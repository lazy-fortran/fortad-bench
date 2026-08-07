#!/usr/bin/env python3
"""Join static and compiler evidence for every pure-Fortran queue candidate.

The result is a deterministic candidate-level handoff.  It deliberately does
not run Tapenade or FortAD and never promotes a ledger status: compiler
acceptance and static entry-point hints remain evidence for the next probe.
Mixed-language candidates are excluded by requiring ``language == fortran``.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_QUEUE = ROOT / "docs/corpora/tapenade-fortran-queue.jsonl"
DEFAULT_COMPILER = ROOT / "docs/corpora/tapenade-fortran-compiler.jsonl"
DEFAULT_STATIC = ROOT / "docs/corpora/tapenade-static.jsonl"
DEFAULT_OUTPUT = ROOT / "docs/corpora/tapenade-fortran-batch.jsonl"
DEFAULT_SUMMARY = ROOT / "docs/corpora/tapenade-fortran-batch.md"
SCHEMA_VERSION = 1
FORTRAN_SUFFIXES = frozenset(
    {".f", ".for", ".ftn", ".f77", ".f90", ".f95", ".f03", ".f08", ".f18", ".f2k", ".inc", ".fh"}
)
IGNORED_FILE_STATUSES = frozenset({"compiled", "include-fragment-not-compiled"})
MISSING_EVIDENCE_STATUSES = frozenset(
    {"checkout-missing", "compiler-unavailable", "missing-source", "timeout"}
)


class BatchError(RuntimeError):
    """An evidence input violates the candidate-level contract."""


def _read_jsonl(path: Path, label: str) -> list[dict]:
    try:
        rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
    except (OSError, json.JSONDecodeError) as exc:
        raise BatchError(f"cannot read {label} {path}: {exc}") from exc
    return rows


def _index(rows: list[dict], label: str) -> dict[tuple[str, str], dict]:
    indexed: dict[tuple[str, str], dict] = {}
    for row in rows:
        key = (row.get("component"), row.get("path"))
        if None in key:
            raise BatchError(f"{label} contains a row without component/path")
        if key in indexed:
            raise BatchError(f"{label} contains duplicate {key[0]}:{key[1]}")
        indexed[key] = row
    return indexed


def _suffix(path: str) -> str:
    return Path(path).suffix.lower()


def _entry_points(static_row: dict) -> list[dict[str, str]]:
    values = []
    for hint in static_row.get("entry_point_hints", []):
        values.append(
            {
                "kind": str(hint.get("kind", "")),
                "name": str(hint.get("name", "")),
                "source": str(hint.get("source", "")),
            }
        )
    return sorted(values, key=lambda item: (item["source"], item["kind"], item["name"]))


def _candidate_status(files: list[dict], missing: list[str]) -> tuple[str, str]:
    if missing:
        return "compiler-report-incomplete", "rerun-compiler-triage"
    if not files:
        return "no-fortran-files", "inspect-candidate"
    problematic = [file for file in files if file.get("status") not in IGNORED_FILE_STATUSES]
    if not problematic:
        return "compiler-clean", "select-entry-point-and-probe"
    if all(file.get("failure_kind") == "missing-dependency" for file in problematic):
        return "compiler-missing-dependency", "resolve-dependency-or-record-refusal"
    if any(file.get("status") in MISSING_EVIDENCE_STATUSES for file in problematic):
        return "compiler-evidence-incomplete", "rerun-compiler-triage"
    return "compiler-errors", "inspect-source-or-record-refusal"


def build_batch(
    queue_rows: list[dict], compiler_rows: list[dict], static_rows: list[dict]
) -> list[dict]:
    queue = _index(queue_rows, "queue")
    compiler = _index(compiler_rows, "compiler report")
    static = _index(static_rows, "static triage")
    pure = [row for row in queue_rows if row.get("language") == "fortran"]
    result = []
    for queue_row in sorted(pure, key=lambda row: (row["component"], row["path"])):
        key = (queue_row["component"], queue_row["path"])
        compiler_row = compiler.get(key)
        if compiler_row is None:
            raise BatchError(f"compiler report is missing {key[0]}:{key[1]}")
        static_row = static.get(key)
        if static_row is None:
            raise BatchError(f"static triage is missing {key[0]}:{key[1]}")
        source_files = sorted(str(path) for path in queue_row.get("source_files", []))
        expected = {path for path in source_files if _suffix(path) in FORTRAN_SUFFIXES}
        compiler_files = []
        for file in compiler_row.get("files", []):
            compiler_files.append(
                {
                    "path": str(file.get("path", "")),
                    "source_kind": str(file.get("source_kind", "")),
                    "status": str(file.get("status", "")),
                    "failure_kind": str(file.get("failure_kind", "")),
                    "diagnostic_hash": str(file.get("diagnostic_hash", "")),
                }
            )
        compiler_files.sort(key=lambda file: file["path"])
        observed = {file["path"] for file in compiler_files}
        missing = sorted(expected - observed)
        extra = sorted(observed - expected)
        candidate_status, next_action = _candidate_status(compiler_files, missing)
        entry_points = _entry_points(static_row)
        if candidate_status == "compiler-clean" and not entry_points:
            next_action = "inspect-entry-point"
        result.append(
            {
                "schema_version": SCHEMA_VERSION,
                "component": queue_row["component"],
                "path": queue_row["path"],
                "language": "fortran",
                "pure_fortran": True,
                "queue_category": queue_row["queue_category"],
                "source_form_hint": queue_row["source_form_hint"],
                "source_files": source_files,
                "entry_point_hints": entry_points,
                "include_hints": sorted(
                    str(hint.get("target", "")) for hint in static_row.get("include_hints", [])
                ),
                "use_hints": sorted(
                    str(hint.get("name", "")) for hint in static_row.get("use_hints", [])
                ),
                "compiler": compiler_row.get("compiler", "unknown"),
                "compiler_version": compiler_row.get("compiler_version", "unknown"),
                "compiler_files": compiler_files,
                "compiler_missing_source_files": missing,
                "compiler_extra_source_files": extra,
                "candidate_status": candidate_status,
                "next_action": next_action,
                "evidence_scope": (
                    "static entry-point/include hints plus individual compiler syntax-only "
                    "evidence; no Tapenade or FortAD transformation, link, runtime, "
                    "or derivative oracle"
                ),
            }
        )
    return result


def render(rows: list[dict]) -> str:
    return "".join(json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n" for row in rows)


def render_summary(rows: list[dict], queue_count: int) -> str:
    statuses = Counter(row["candidate_status"] for row in rows)
    files = Counter(file["status"] for row in rows for file in row["compiler_files"])
    no_entry = sum(not row["entry_point_hints"] for row in rows)
    lines = [
        "# Pure-Fortran Tapenade batch manifest",
        "",
        f"This report joins static and compiler evidence for `{len(rows):,}` pure-Fortran candidates from a `{queue_count:,}`-row queue. Mixed-language candidates are excluded.",
        "",
        "It is an evidence-only handoff. `compiler-clean` means each listed source was accepted by the recorded syntax-only compiler (apart from include fragments, which are not standalone units). It does not claim Tapenade parsing, FortAD support, linking, runtime behavior, or derivative correctness.",
        "",
        "Regenerate and check it with:",
        "",
        "```bash",
        "scripts/batch_tapenade_fortran.py",
        "scripts/batch_tapenade_fortran.py --check",
        "```",
        "",
        "## Candidate status",
        "",
        "| status | candidates |",
        "|---|---:|",
    ]
    for status in sorted(statuses):
        lines.append(f"| `{status}` | {statuses[status]} |")
    lines += [
        "",
        "## Compiler file status",
        "",
        "| status | files |",
        "|---|---:|",
    ]
    for status in sorted(files):
        lines.append(f"| `{status}` | {files[status]} |")
    lines += [
        "",
        f"Candidates without a static entry-point hint: **{no_entry}**.",
        "Each row carries the exact source paths, sorted entry-point hints, compiler diagnostic hashes, missing/extra source paths, and a bounded `next_action`. No row changes the status ledger.",
        "",
    ]
    return "\n".join(lines)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--queue", type=Path, default=DEFAULT_QUEUE)
    parser.add_argument("--compiler-report", type=Path, default=DEFAULT_COMPILER)
    parser.add_argument("--static-triage", type=Path, default=DEFAULT_STATIC)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--check", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        queue = _read_jsonl(args.queue, "queue")
        compiler = _read_jsonl(args.compiler_report, "compiler report")
        static = _read_jsonl(args.static_triage, "static triage")
        rows = build_batch(queue, compiler, static)
        rendered = render(rows)
        summary = render_summary(rows, len(queue))
        if args.check:
            if not args.output.is_file() or args.output.read_text(encoding="utf-8") != rendered:
                raise BatchError(f"{args.output} differs from deterministic batch manifest")
            if not args.summary.is_file() or args.summary.read_text(encoding="utf-8") != summary:
                raise BatchError(f"{args.summary} differs from deterministic batch summary")
            return 0
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
        args.summary.write_text(summary, encoding="utf-8")
    except BatchError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
