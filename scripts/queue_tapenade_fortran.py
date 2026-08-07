#!/usr/bin/env python3
"""Build an evidence-neutral work queue for untriaged Fortran Tapenade rows.

This command only consumes the committed static triage and status ledger.  It
does not invoke Tapenade, FortAD, a compiler, or a numerical oracle.  Every
label is therefore a candidate/risk label, never a support or parse result.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TRIAGE = ROOT / "docs" / "corpora" / "tapenade-static.jsonl"
DEFAULT_LEDGER = ROOT / "docs" / "corpora" / "tapenade-status.csv"
DEFAULT_QUEUE = ROOT / "docs" / "corpora" / "tapenade-fortran-queue.jsonl"
DEFAULT_SUMMARY = ROOT / "docs" / "corpora" / "tapenade-fortran-queue.md"
SCHEMA_VERSION = 1
LEDGER_COLUMNS = (
    "component",
    "path",
    "language",
    "source_form_hint",
    "initial_classification",
    "status",
    "entry_point",
    "tapenade_options",
    "modes",
    "oracle",
    "dependencies",
    "tapenade_result",
    "fortad_result",
)
FORTRAN_LANGUAGES = frozenset({"fortran", "c|fortran", "c++|fortran"})
FORTRAN_SUFFIXES = frozenset(
    {".f", ".for", ".ftn", ".f77", ".f90", ".f95", ".f03", ".f08", ".f18", ".f2k"}
)
DERIVATIVE_NAME_RE = re.compile(
    r"(?:^|[_-])(?:b|d|p|dv|fwd|bwd|aad|adj)(?:[_-]|$)", re.IGNORECASE
)
QUEUE_BUCKETS = (
    "mixed-language-risk",
    "parser-or-invalid-risk",
    "reference-only-evidence",
    "no-entry-point-evidence",
    "runnable-program-candidate",
    "runnable-procedure-candidate",
    "needs-static-inspection",
)


class QueueError(RuntimeError):
    """The static report and ledger cannot form a safe queue."""


def read_triage(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as stream:
        rows = [json.loads(line) for line in stream]
    keys = [(row["component"], row["path"]) for row in rows]
    if len(keys) != len(set(keys)):
        raise QueueError("static triage contains duplicate candidate keys")
    return rows


def read_ledger(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        if tuple(reader.fieldnames or ()) != LEDGER_COLUMNS:
            raise QueueError("status ledger columns differ from schema")
        return list(reader)


def _entry_kinds(row: dict) -> list[str]:
    return sorted({entry["kind"] for entry in row.get("entry_point_hints", [])})


def _local_include_targets(row: dict) -> set[str]:
    return {
        Path(source).name.casefold()
        for source in row.get("source_files", [])
    }


def _unresolved_include_hints(row: dict) -> list[str]:
    local = _local_include_targets(row)
    return sorted({
        include["target"]
        for include in row.get("include_hints", [])
        if Path(include["target"]).name.casefold() not in local
    })


def _reference_only_evidence(row: dict) -> bool:
    """Return true only for the narrow derivative-only filename pattern.

    A missing entry-point hint alone is deliberately not enough: the static
    extractor can miss multiline or otherwise unusual declarations.
    """
    sources = [
        Path(path)
        for path in row.get("source_files", [])
        if Path(path).suffix.casefold() in FORTRAN_SUFFIXES
    ]
    if not sources or row.get("entry_point_hints"):
        return False
    return all(DERIVATIVE_NAME_RE.search(source.stem) for source in sources)


def classify_row(row: dict, ledger_row: dict[str, str]) -> dict[str, object] | None:
    """Classify one row using only static hints; return None when out of queue."""
    if ledger_row["status"] != "untriaged":
        return None
    language = row["language"]
    if language not in FORTRAN_LANGUAGES:
        return None

    kinds = _entry_kinds(row)
    unresolved_includes = _unresolved_include_hints(row)
    reference_only = _reference_only_evidence(row)
    if "|" in language:
        category = "mixed-language-risk"
        rank = 10
        rationale = "static language hint contains Fortran and another language"
    elif ledger_row["component"] == "fortran-known-failures":
        category = "parser-or-invalid-risk"
        rank = 20
        rationale = "manifest component is historical Fortran issue/expected-failure material"
    elif reference_only:
        category = "reference-only-evidence"
        rank = 30
        rationale = "all detected Fortran source names are derivative/reference-shaped and no entry hint was found"
    elif not kinds:
        category = "no-entry-point-evidence"
        rank = 31
        rationale = "no program, subroutine, or function hint was found by the static extractor"
    elif "program" in kinds:
        category = "runnable-program-candidate"
        rank = 40
        rationale = "a static program declaration hint was found"
    elif set(kinds).intersection({"subroutine", "function"}):
        category = "runnable-procedure-candidate"
        rank = 50
        rationale = "a static subroutine/function declaration hint was found"
    else:
        category = "needs-static-inspection"
        rank = 60
        rationale = "the static hints do not fit a queue category"

    risk_flags: list[str] = []
    if "|" in language:
        risk_flags.append("mixed-language-source")
    if ledger_row["component"] == "fortran-known-failures":
        risk_flags.append("historical-failure-component")
    if not kinds:
        risk_flags.append("no-entry-point-hint")
    if reference_only:
        risk_flags.append("derivative-only-source-names")
    if unresolved_includes:
        risk_flags.append("include-target-not-local")
    risk_flags.sort()
    risk_categories = [category]
    if unresolved_includes:
        risk_categories.append("missing-dependency-risk")
    return {
        "schema_version": SCHEMA_VERSION,
        "component": row["component"],
        "path": row["path"],
        "language": language,
        "source_form_hint": row["source_form_hint"],
        "static_classification": row["classification"],
        "queue_category": category,
        "queue_rank": rank,
        "rationale": rationale,
        "entry_point_kinds": kinds,
        "entry_point_hint_count": len(row.get("entry_point_hints", [])),
        "source_file_count": len(row.get("source_files", [])),
        "source_files": row.get("source_files", []),
        "include_hints": sorted({include["target"] for include in row.get("include_hints", [])}),
        "unresolved_include_hints": unresolved_includes,
        "use_hints": sorted({use["name"] for use in row.get("use_hints", [])}),
        "risk_flags": risk_flags,
        "risk_categories": sorted(risk_categories),
        "dependency_risk": bool(unresolved_includes),
        "evidence_scope": "static filenames and line-based declaration/include/use hints only",
    }


def build_queue(ledger_rows: list[dict[str, str]], triage_rows: list[dict]) -> list[dict[str, object]]:
    ledger = {(row["component"], row["path"]): row for row in ledger_rows}
    triage_keys = {(row["component"], row["path"]) for row in triage_rows}
    if set(ledger) != triage_keys:
        raise QueueError("static triage and status ledger keys differ")
    queue = []
    for row in triage_rows:
        classified = classify_row(row, ledger[(row["component"], row["path"])])
        if classified is not None:
            queue.append(classified)
    return sorted(queue, key=lambda row: (row["queue_rank"], row["component"], row["path"]))


def render_queue(rows: list[dict[str, object]]) -> str:
    return "".join(
        json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n"
        for row in rows
    )


def render_summary(rows: list[dict[str, object]]) -> str:
    categories = Counter(row["queue_category"] for row in rows)
    languages = Counter(row["language"] for row in rows)
    dependency_rows = sum(bool(row["dependency_risk"]) for row in rows)
    unresolved_targets = Counter(
        target
        for row in rows
        for target in row["unresolved_include_hints"]
    )
    lines = [
        "# Tapenade Fortran queue",
        "",
        "This is a deterministic, evidence-neutral queue for the currently "
        f"untriaged rows ({len(rows)} candidates). It reads only the committed "
        "static triage and status ledger; it does not run a compiler, Tapenade, "
        "FortAD, or an oracle.",
        "",
        "Regenerate and check it with:",
        "",
        "```bash",
        "scripts/queue_tapenade_fortran.py",
        "scripts/queue_tapenade_fortran.py --check",
        "```",
        "",
        "## Queue buckets",
        "",
        "The first matching rule wins:",
        "",
        "1. `mixed-language-risk`: the filename language hint contains Fortran and another language.",
        "2. `parser-or-invalid-risk`: the manifest marks the row as a historical Fortran issue/expected-failure component; this does not prove a parser failure.",
        "3. `reference-only-evidence`: every detected Fortran source name is derivative-shaped and no entry hint was found.",
        "4. `no-entry-point-evidence`: the extractor found no program, subroutine, or function hint; this is not proof that no entry point exists.",
        "5. `runnable-program-candidate`: a program declaration hint was found.",
        "6. `runnable-procedure-candidate`: a subroutine/function declaration hint was found.",
        "7. `needs-static-inspection`: residual rows that do not match these rules.",
        "",
        "| queue bucket | rows |",
        "|---|---:|",
    ]
    for category in QUEUE_BUCKETS:
        count = categories[category]
        lines.append(f"| `{category}` | {count} |")
    lines += [
        "",
        "## Language and dependency signals",
        "",
        "| language hint | rows |",
        "|---|---:|",
    ]
    for language, count in sorted(languages.items()):
        lines.append(f"| `{language}` | {count} |")
    lines += [
        "",
        f"`{dependency_rows}` rows carry the orthogonal `missing-dependency-risk` "
        "category because an include target's basename is "
        "not present among that candidate's tracked source/include files. This "
        "is a dependency risk signal, not proof that the dependency is absent; "
        "system headers and shared runtime files may be supplied externally.",
        "",
        "Most frequent unresolved include hints:",
        "",
    ]
    for target, count in unresolved_targets.most_common(12):
        lines.append(f"- `{target}` ({count} rows)")
    lines += [
        "",
        "## Interpretation",
        "",
        "The program/procedure buckets identify the next candidates for actual "
        "entry-point inspection and compiler-backed runs. The mixed and "
        "historical-failure buckets should be isolated first so a missing C/C++ "
        "boundary or known Tapenade failure is not mistaken for a FortAD result. "
        "Static hints include checked-in reference derivatives, can miss multiline "
        "declarations, and do not resolve modules or build systems. Every row "
        "remains `untriaged` until a compiler, transformation, runtime, and "
        "independent oracle provide evidence in the status ledger.",
        "",
        "The machine-readable rows are in `tapenade-fortran-queue.jsonl`.",
        "",
    ]
    return "\n".join(lines)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--triage", type=Path, default=DEFAULT_TRIAGE)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--queue", type=Path, default=DEFAULT_QUEUE)
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--check", action="store_true", help="fail if checked-in outputs are stale")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    rows = build_queue(read_ledger(arguments.ledger), read_triage(arguments.triage))
    queue = render_queue(rows)
    summary = render_summary(rows)
    if arguments.check:
        stale = []
        if arguments.queue.read_text(encoding="utf-8") != queue:
            stale.append(str(arguments.queue))
        if arguments.summary.read_text(encoding="utf-8") != summary:
            stale.append(str(arguments.summary))
        if stale:
            print("stale Tapenade Fortran queue outputs: " + ", ".join(stale))
            return 1
    else:
        arguments.queue.write_text(queue, encoding="utf-8")
        arguments.summary.write_text(summary, encoding="utf-8")
    print(f"queued {len(rows)} rows across {len(Counter(row['queue_category'] for row in rows))} buckets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
