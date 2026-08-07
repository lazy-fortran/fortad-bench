#!/usr/bin/env python3
"""Compile every queued Tapenade Fortran source as syntax-only evidence.

This command deliberately stops at the compiler boundary.  A successful
``gfortran -fsyntax-only`` invocation says only that the individual source
file was accepted by this compiler with the recorded flags; it is not a
transformation, runtime, or derivative-support claim.

The report is JSONL sorted by ``(component, path, source path)``.  A shard is
selected by the stable candidate index, so reports generated independently on
different workers can be merged without depending on completion order.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CHECKOUT = ROOT / "upstream" / "tapenade"
DEFAULT_QUEUE = ROOT / "docs" / "corpora" / "tapenade-fortran-queue.jsonl"
DEFAULT_REPORT = ROOT / "docs" / "corpora" / "tapenade-fortran-compiler.jsonl"
DEFAULT_SUMMARY = ROOT / "docs" / "corpora" / "tapenade-fortran-compiler.md"
SCHEMA_VERSION = 1

FIXED_SUFFIXES = frozenset({".f", ".for", ".ftn", ".f77"})
FREE_SUFFIXES = frozenset({".f90", ".f95", ".f03", ".f08", ".f18", ".f2k"})
INCLUDE_SUFFIXES = frozenset({".inc", ".fh"})
FORTRAN_SUFFIXES = FIXED_SUFFIXES | FREE_SUFFIXES
CPP_SUFFIXES = frozenset({".F", ".FOR", ".FTN", ".F77", ".F90", ".F95", ".F03", ".F08", ".F18", ".F2K"})
TEMP_PATH_RE = re.compile(r"/(?:tmp|var/tmp)/[^\s:]+")
MISSING_DEPENDENCY_RE = re.compile(
    r"cannot open (?:included|module) file|can't open included file|"
    r"no such file or directory",
    re.IGNORECASE,
)


class TriageError(RuntimeError):
    """The queue, checkout, or report violates the deterministic contract."""


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def _safe_relative(path: str) -> Path:
    candidate = Path(path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise TriageError(f"unsafe corpus path: {path!r}")
    return candidate


def read_queue(path: Path) -> list[dict]:
    try:
        rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
    except (OSError, json.JSONDecodeError) as exc:
        raise TriageError(f"cannot read queue {path}: {exc}") from exc
    keys = [(row.get("component"), row.get("path")) for row in rows]
    if any(None in key for key in keys) or len(keys) != len(set(keys)):
        raise TriageError("queue contains missing or duplicate candidate keys")
    for row in rows:
        _safe_relative(str(row["path"]))
        for source in row.get("source_files", []):
            _safe_relative(str(source))
    return sorted(rows, key=lambda row: (row["component"], row["path"]))


def _source_kind(path: str) -> str:
    suffix = Path(path).suffix
    normalized = suffix.lower()
    if normalized in FIXED_SUFFIXES:
        return "fixed"
    if normalized in FREE_SUFFIXES:
        return "free"
    if normalized in INCLUDE_SUFFIXES:
        return "include-fragment"
    return "not-fortran"


def _compiler_version(compiler: str) -> str:
    try:
        result = subprocess.run(
            [compiler, "--version"],
            check=False,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=15,
            env=_compiler_environment(),
        )
    except (OSError, subprocess.TimeoutExpired):
        return "unavailable"
    first = (result.stdout or result.stderr).splitlines()
    return first[0].strip() if first else "unknown"


def _normalise_diagnostic(text: str, checkout: Path, scratch: Path | None = None) -> str:
    """Make compiler output independent of checkout/worktree absolute paths."""
    if not isinstance(text, str):
        text = text.decode("utf-8", errors="replace")
    result = text.replace("\r\n", "\n").replace("\r", "\n")
    checkout_text = str(checkout.resolve()).replace("\\", "/")
    result = result.replace(checkout_text, "<checkout>")
    # gfortran can report the current working directory in a few diagnostics;
    # normalise it without changing source line/column information.
    result = result.replace(str(checkout).replace("\\", "/"), "<checkout>")
    if scratch is not None:
        scratch_text = str(scratch.resolve()).replace("\\", "/")
        result = result.replace(scratch_text, "<scratch>")
        result = result.replace(str(scratch).replace("\\", "/"), "<scratch>")
    # GCC embeds random preprocessor/backtrace paths such as
    # ``/tmp/ccAB12.fii`` in internal-error diagnostics.  They are execution
    # scratch, not corpus evidence, and must not make the hash nondeterministic.
    result = TEMP_PATH_RE.sub("<tmp>", result)
    result = "\n".join(line.rstrip() for line in result.splitlines())
    return result.strip() + ("\n" if result.strip() else "")


def _compiler_environment() -> dict[str, str]:
    environment = os.environ.copy()
    environment.update({"LANG": "C", "LC_ALL": "C", "GFORTRAN_COLORS": ""})
    environment.pop("GCC_COLORS", None)
    return environment


def _include_roots(checkout: Path, candidate_path: str, source_paths: list[str]) -> list[str]:
    roots = {Path(".")}
    candidate = _safe_relative(candidate_path)
    # A Tapenade candidate can be either a case directory or a standalone
    # source file. Passing a file itself to ``-I`` produces a misleading
    # missing-directory diagnostic, so use its parent in the latter case.
    roots.add(candidate.parent if candidate_path in source_paths else candidate)
    for source in source_paths:
        source_path = _safe_relative(source)
        roots.add(source_path.parent)
    # Include directories must be relative to the subprocess cwd so reports
    # never contain an absolute path.  Parent directories are bounded by the
    # checkout and therefore cannot escape the corpus.
    return sorted(path.as_posix() for path in roots)


def _flags(kind: str, path: str, include_roots: list[str]) -> list[str]:
    if kind == "fixed":
        flags = ["-std=f2018", "-ffixed-form"]
    else:
        flags = ["-std=f2018", "-ffree-form"]
    flags += [
        "-fsyntax-only",
        "-pedantic-errors",
        "-Wall",
        "-Wextra",
        "-Wimplicit-interface",
        "-cpp",
    ]
    for root in include_roots:
        flags.append(f"-I{root}")
    return flags


def _missing_file_record(
    path: str,
    kind: str,
    status: str,
    reason: str,
    flags: list[str] | None = None,
) -> dict:
    diagnostic = reason.rstrip() + "\n"
    return {
        "path": path,
        "source_kind": kind,
        "status": status,
        "exit_code": None,
        "failure_kind": status,
        "compile_flags": flags or [],
        "diagnostic_hash": _sha256(diagnostic),
        "diagnostic_lines": len(diagnostic.splitlines()),
    }


def _compile_one(
    compiler: str,
    checkout: Path,
    source: str,
    kind: str,
    include_roots: list[str],
    timeout: float,
) -> dict:
    flags = _flags(kind, source, include_roots) if kind != "include-fragment" else []
    if kind == "include-fragment":
        return _missing_file_record(
            source,
            kind,
            "include-fragment-not-compiled",
            "include fragment is not a standalone translation unit",
        )
    source_path = checkout / _safe_relative(source)
    if not source_path.is_file():
        return _missing_file_record(
            source, kind, "missing-source", "source file is not present", flags
        )
    # ``gfortran -fsyntax-only`` can still emit module files. Give every
    # source its own ephemeral module directory so one file's generated
    # interface cannot change the next file's result or dirty the checkout.
    scratch_parent = Path("/var/tmp/ert")
    scratch_parent_arg = scratch_parent if scratch_parent.is_dir() else None
    with tempfile.TemporaryDirectory(
        prefix="fortad-triage-mod-", dir=scratch_parent_arg
    ) as module_dir:
        report_flags = [*flags, "-J<scratch>"]
        command = [compiler, *flags, f"-J{module_dir}", source]
        try:
            result = subprocess.run(
                command,
                cwd=checkout,
                check=False,
                capture_output=True,
                text=True,
                errors="replace",
                timeout=timeout,
                env=_compiler_environment(),
            )
        except FileNotFoundError:
            return _missing_file_record(
                source, kind, "compiler-unavailable", "compiler is unavailable", report_flags
            )
        except subprocess.TimeoutExpired as exc:
            diagnostic = _normalise_diagnostic(
                (exc.stdout or "") + (exc.stderr or "") + "compiler timeout\n",
                checkout,
                Path(module_dir),
            )
            return {
                "path": source,
                "source_kind": kind,
                "status": "timeout",
                "exit_code": None,
                "failure_kind": "compiler-timeout",
                "compile_flags": report_flags,
                "diagnostic_hash": _sha256(diagnostic),
                "diagnostic_lines": len(diagnostic.splitlines()),
            }
        diagnostic = _normalise_diagnostic(
            (result.stdout or "") + (result.stderr or ""), checkout, Path(module_dir)
        )
        return {
            "path": source,
            "source_kind": kind,
            "status": "compiled" if result.returncode == 0 else "syntax-error",
            "exit_code": result.returncode,
            "failure_kind": (
                "none"
                if result.returncode == 0
                else "missing-dependency"
                if MISSING_DEPENDENCY_RE.search(diagnostic)
                else "compiler-diagnostic"
            ),
            "compile_flags": report_flags,
            "diagnostic_hash": _sha256(diagnostic),
            "diagnostic_lines": len(diagnostic.splitlines()),
        }


def _candidate(
    row: dict,
    compiler: str,
    compiler_version: str,
    checkout: Path,
    timeout: float,
) -> dict:
    source_files = sorted(str(path) for path in row.get("source_files", []))
    fortran_sources = [(source, _source_kind(source)) for source in source_files]
    fortran_sources = [(source, kind) for source, kind in fortran_sources if kind != "not-fortran"]
    ignored = [source for source in source_files if _source_kind(source) == "not-fortran"]
    roots = _include_roots(checkout, str(row["path"]), source_files)
    if not checkout.is_dir():
        files = [
            _missing_file_record(
                source,
                kind,
                "checkout-missing",
                "Tapenade checkout is not present",
                _flags(kind, source, roots) if kind != "include-fragment" else [],
            )
            for source, kind in fortran_sources
        ]
    else:
        files = [_compile_one(compiler, checkout, source, kind, roots, timeout) for source, kind in fortran_sources]
    files.sort(key=lambda value: value["path"])
    return {
        "schema_version": SCHEMA_VERSION,
        "component": row["component"],
        "path": row["path"],
        "language": row["language"],
        "queue_category": row["queue_category"],
        "source_form_hint": row["source_form_hint"],
        "compiler": Path(compiler).name,
        "compiler_version": compiler_version,
        "include_roots": roots,
        "files": files,
        "ignored_non_fortran_files": ignored,
        "evidence_scope": "individual gfortran syntax-only compile; no transformation, runtime, or derivative oracle",
    }


def _shard(rows: list[dict], index: int, count: int) -> list[dict]:
    if count < 1 or not 0 <= index < count:
        raise TriageError("shard index must satisfy 0 <= index < shard count")
    selected = []
    for row in rows:
        key = f"{row['component']}\0{row['path']}".encode("utf-8")
        bucket = int.from_bytes(hashlib.sha256(key).digest()[:8], "big") % count
        if bucket == index:
            selected.append(row)
    return selected


def build_report(
    rows: list[dict], compiler: str, checkout: Path, timeout: float, jobs: int,
    shard_index: int = 0, shard_count: int = 1,
) -> list[dict]:
    selected = _shard(rows, shard_index, shard_count)
    version = _compiler_version(compiler)
    if jobs < 1:
        raise TriageError("jobs must be positive")
    reports: list[dict] = []
    if jobs == 1:
        reports = [_candidate(row, compiler, version, checkout, timeout) for row in selected]
    else:
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            futures = {
                pool.submit(_candidate, row, compiler, version, checkout, timeout): row
                for row in selected
            }
            for future in as_completed(futures):
                reports.append(future.result())
    return sorted(reports, key=lambda row: (row["component"], row["path"]))


def render_report(rows: list[dict]) -> str:
    return "".join(json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n" for row in rows)


def read_report(path: Path) -> list[dict]:
    try:
        rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
    except (OSError, json.JSONDecodeError) as exc:
        raise TriageError(f"cannot read report {path}: {exc}") from exc
    keys = [(row.get("component"), row.get("path")) for row in rows]
    if any(None in key for key in keys) or len(keys) != len(set(keys)):
        raise TriageError(f"report {path} has missing or duplicate candidate keys")
    for row in rows:
        file_paths = [file.get("path") for file in row.get("files", [])]
        if len(file_paths) != len(set(file_paths)):
            raise TriageError(f"report {path} has duplicate source paths")
    return rows


def merge_reports(paths: list[Path], queue_rows: list[dict]) -> list[dict]:
    merged: dict[tuple[str, str], dict] = {}
    for path in paths:
        for row in read_report(path):
            key = (row["component"], row["path"])
            if key in merged:
                raise TriageError(f"duplicate candidate in shard reports: {key[0]}:{key[1]}")
            merged[key] = row
    expected = {(row["component"], row["path"]) for row in queue_rows}
    if set(merged) != expected:
        missing = sorted(expected - set(merged))
        extra = sorted(set(merged) - expected)
        raise TriageError(f"shards do not cover queue (missing={len(missing)}, extra={len(extra)})")
    return [merged[key] for key in sorted(merged)]


def render_summary(rows: list[dict], *, queue_count: int, compiler: str, checkout: Path, shard: str = "full") -> str:
    statuses = Counter(file["status"] for row in rows for file in row["files"])
    failures = Counter(file["failure_kind"] for row in rows for file in row["files"])
    source_kinds = Counter(file["source_kind"] for row in rows for file in row["files"])
    lines = [
        "# Tapenade compiler-backed Fortran triage",
        "",
        f"This report covers `{len(rows):,}` of `{queue_count:,}` queued candidates (`{shard}`). It runs each tracked Fortran source as an individual `gfortran -fsyntax-only -std=f2018 -pedantic-errors` check. A `compiled` row is compiler acceptance only. It is not evidence that Tapenade, FortAD, a runtime, or derivatives work.",
        "",
        "The checkout is the pinned Tapenade revision named in `docs/corpora/tapenade.toml`. Source form is selected by suffix (`.f`/`.for` fixed, `.f90`/`.f03`/similar free). Candidate-local source/include directories and the checkout root are passed as `-I` roots. Paths, command flags, and diagnostic hashes are deterministic. Compiler identity is recorded explicitly because diagnostics can vary by compiler release.",
        "",
        "Regenerate the full report:",
        "",
        "```bash",
        "scripts/fetch_upstreams.py tapenade",
        "scripts/triage_tapenade_fortran.py --jobs 4",
        "scripts/triage_tapenade_fortran.py --check",
        "```",
        "",
        "## File status",
        "",
        "| status | files |",
        "|---|---:|",
    ]
    for status in sorted(statuses):
        lines.append(f"| `{status}` | {statuses[status]} |")
    lines += [
        "",
        "## Failure kind",
        "",
        "| kind | files |",
        "|---|---:|",
    ]
    for failure in sorted(failures):
        lines.append(f"| `{failure}` | {failures[failure]} |")
    lines += [
        "",
        "## Source kinds",
        "",
        "| kind | files |",
        "|---|---:|",
    ]
    for kind in sorted(source_kinds):
        lines.append(f"| `{kind}` | {source_kinds[kind]} |")
    lines += [
        "",
        "`syntax-error`, `missing-source`, `checkout-missing`, `timeout`, and `compiler-unavailable` are evidence statuses, not support/refusal classifications. A `missing-dependency` failure is inferred only from compiler diagnostic text (`include`/`module` open failures). It is not a claim that the dependency is absent. Include fragments are listed but intentionally not compiled as standalone translation units. Each source is checked independently, so a sibling `use` without a pre-existing local `.mod` is reported as dependency evidence rather than silently treated as a candidate-level failure or success.",
        "",
        f"Compiler: `{Path(compiler).name}`. The checkout path is intentionally omitted from this summary so copies of the pinned checkout remain comparable. Diagnostic hashes are SHA-256 of normalized compiler output. An empty diagnostic has the SHA-256 empty-string hash.",
        "",
        "Rows are sorted by candidate identity and each file list is sorted by source path. They contain no temporary or absolute paths, so shard reports can be merged with `--merge-input` without depending on worker completion order.",
        "",
    ]
    return "\n".join(lines)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkout", type=Path, default=DEFAULT_CHECKOUT)
    parser.add_argument("--queue", type=Path, default=DEFAULT_QUEUE)
    parser.add_argument("--output", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--compiler", default="gfortran")
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument("--shard-count", type=int, default=1)
    parser.add_argument("--merge-input", action="append", type=Path, default=[])
    parser.add_argument("--check", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        queue_rows = read_queue(args.queue)
        if args.merge_input:
            reports = merge_reports(args.merge_input, queue_rows)
            summary = render_summary(reports, queue_count=len(queue_rows), compiler="merged", checkout=args.checkout, shard="merged shards")
        else:
            reports = build_report(
                queue_rows,
                args.compiler,
                args.checkout,
                args.timeout,
                args.jobs,
                args.shard_index,
                args.shard_count,
            )
            shard = f"shard {args.shard_index + 1}/{args.shard_count}" if args.shard_count > 1 else "full queue"
            summary = render_summary(reports, queue_count=len(queue_rows), compiler=args.compiler, checkout=args.checkout, shard=shard)
        rendered = render_report(reports)
        if args.check:
            if not args.output.is_file() or args.output.read_text(encoding="utf-8") != rendered:
                raise TriageError(f"{args.output} differs from deterministic compiler report")
            if not args.summary.is_file() or args.summary.read_text(encoding="utf-8") != summary:
                raise TriageError(f"{args.summary} differs from deterministic compiler summary")
            return 0
        write_text(args.output, rendered)
        write_text(args.summary, summary)
    except TriageError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
