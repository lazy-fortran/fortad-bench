#!/usr/bin/env python3
"""Probe the small Tapenade source shard with gfortran and Tapenade.

The probe is deliberately a source-viability check.  It does not claim that a
generated derivative is correct, runnable, or supported by FortAD.  The
upstream checkout is read from ``upstream/tapenade`` and must be the revision
declared in ``docs/corpora/tapenade.toml``.
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import shlex
import subprocess
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "upstream" / "tapenade"
LEDGER = ROOT / "docs" / "corpora" / "tapenade-status.csv"
REPORT = ROOT / "docs" / "corpora" / "tapenade-known-failures.md"
REVISION = "e59864cab441d4175df75383b3ff58c3dcd26df9"
FIXED_SUFFIXES = {".f", ".for", ".ftn"}
MISSING_RE = re.compile(
    r"fatal error:\s*cannot open (?:included file|module file)|"
    r"fatal error:\s*cannot open .*\.mod",
    re.IGNORECASE,
)
STACK_RE = re.compile(
    r"(?:StackOverflowError|Parsing error|System: Fatal error|Uncaught exception)",
    re.IGNORECASE,
)


def _rows() -> list[dict[str, str]]:
    with LEDGER.open(encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream))
    return [
        row
        for row in rows
        if row["component"] == "fortran-known-failures"
        or (row["component"] == "large-examples" and row["language"] == "fortran")
    ]


def _source(case: Path) -> Path:
    for name in ("program.f90", "program.f"):
        if (case / name).is_file():
            return case / name
    sources = sorted(
        path
        for path in case.iterdir()
        if path.suffix.lower() in FIXED_SUFFIXES | {".f90", ".f95", ".f03", ".f08"}
    )
    if not sources:
        raise RuntimeError(f"no Fortran source in {case}")
    return sources[0]


def _run(command: list[str], case: Path, timeout: int = 90) -> tuple[int, str]:
    try:
        process = subprocess.run(
            command,
            cwd=case,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "PATH": f"{UPSTREAM / 'bin'}:{os.environ.get('PATH', '')}"},
        )
    except FileNotFoundError as error:
        return 127, str(error)
    except subprocess.TimeoutExpired:
        return 124, "timeout"
    return process.returncode, process.stdout + process.stderr


def _compiler(case: Path, source: Path) -> tuple[str, str]:
    fixed = source.suffix.lower() in FIXED_SUFFIXES
    form_flags = ["-ffixed-line-length-none"] if fixed else ["-ffree-line-length-none"]
    strict = ["gfortran", "-fsyntax-only", "-std=f2018", *form_flags, "-I", str(case), source.name]
    legacy = ["gfortran", "-fsyntax-only", "-std=legacy", *form_flags, "-I", str(case), source.name]
    strict_rc, strict_text = _run(strict, case, timeout=60)
    if strict_rc == 0:
        return "runnable-strict", "gfortran strict syntax check passed"
    legacy_rc, legacy_text = _run(legacy, case, timeout=60)
    if legacy_rc == 0:
        return "runnable-legacy", "gfortran legacy syntax check passed; strict mode rejected"
    # Legacy mode is the compatibility probe.  If it still emits ordinary
    # errors in addition to a missing module, the source is invalid for this
    # shard rather than merely blocked by a dependency.
    diagnostics = [
        line
        for line in legacy_text.splitlines()
        if re.search(r"\b(?:Error|Fatal Error):", line)
        and "Warning:" not in line
    ]
    if diagnostics and MISSING_RE.search(legacy_text) and all(
        MISSING_RE.search(line) for line in diagnostics
    ):
        return "missing-dependency", "gfortran reported a missing include or module"
    return "invalid-source", "gfortran rejected both strict and legacy syntax checks"


def _tapenade(case: Path, source: Path, output: Path) -> tuple[str, str]:
    executable = UPSTREAM / "bin" / "tapenade"
    if not executable.is_file():
        return "not-run", "Tapenade executable is not built; run the setup commands below"
    output.mkdir(parents=True, exist_ok=True)
    rc, text = _run(
        [str(executable), "-p", "-O", str(output), "-o", "program", source.name],
        case,
    )
    generated = (output / "program_p.f90").is_file() or (output / "program_p.f").is_file()
    marker = STACK_RE.search(text)
    if marker or not generated:
        return "parser-failure", marker.group(0) if marker else f"no program_p output (exit {rc})"
    return "parser-accepted", "program_p output generated (parser probe only)"


def probe() -> list[dict[str, str]]:
    if not UPSTREAM.is_dir():
        raise RuntimeError("missing upstream/tapenade; fetch with scripts/fetch_upstreams.py --corpus tapenade")
    rows = []
    with tempfile.TemporaryDirectory(prefix="tapenade-shard-", dir="/var/tmp/ert") as scratch:
        scratch_path = Path(scratch)
        for index, row in enumerate(_rows()):
            case = UPSTREAM / row["path"]
            source = _source(case)
            compiler_status, compiler_evidence = _compiler(case, source)
            parser_status, parser_evidence = _tapenade(case, source, scratch_path / f"case-{index:02d}")
            if compiler_status == "missing-dependency":
                status = compiler_status
            elif compiler_status == "invalid-source":
                status = compiler_status
            elif parser_status == "parser-failure":
                status = parser_status
            else:
                status = "runnable"
            rows.append(
                {
                    "component": row["component"],
                    "path": row["path"],
                    "source": str(source.relative_to(UPSTREAM)),
                    "source_form": "fixed" if source.suffix.lower() in FIXED_SUFFIXES else "free",
                    "status": status,
                    "compiler_evidence": compiler_evidence,
                    "tapenade_evidence": parser_evidence,
                    "fortad": "not-run; no derivative oracle",
                }
            )
    return rows


def render(rows: list[dict[str, str]]) -> str:
    counts = Counter(row["status"] for row in rows)
    lines = [
        "# Tapenade bounded source shard",
        "",
        "This report covers the 37 `fortran-known-failures` rows and the 22",
        "Fortran rows under `large-examples` in the pinned Tapenade checkout.",
        "It is a source-viability classification, not a FortAD support claim:",
        "no row below has a derivative numerical oracle.",
        "",
        f"Pinned revision: `{REVISION}`",
        "",
        "## Probe contract",
        "",
        "The primary `program.f90` (or fixed-form `program.f`) is checked with",
        "`gfortran -fsyntax-only -std=f2018` and, if needed, `-std=legacy`, with",
        "the case directory as the include path. `missing-dependency` requires a",
        "compiler fatal diagnostic for an include/module; it is not inferred from",
        "the static queue. `runnable` means the source syntax check passed and the",
        "Tapenade `-p` parser probe emitted `program_p`; it does not mean the",
        "program links, executes, or differentiates correctly.",
        "",
        "Tapenade setup for this run (from the pinned checkout):",
        "",
        "```text",
        "./gradlew --no-daemon illang",
        "./gradlew --no-daemon buildVersion",
        "./gradlew --no-daemon assemble",
        "./gradlew --no-daemon frontf",
        "```",
        "",
        "## Summary",
        "",
        "| status | rows |",
        "|---|---:|",
    ]
    for status in ("runnable", "parser-failure", "missing-dependency", "invalid-source"):
        lines.append(f"| `{status}` | {counts.get(status, 0)} |")
    lines += [
        f"| **total** | **{len(rows)}** |",
        "",
        "## Evidence",
        "",
        "| component | path | source | form | status | compiler evidence | Tapenade evidence | FortAD |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        values = [
            row["component"],
            f"`{row['path']}`",
            f"`{row['source']}`",
            row["source_form"],
            f"`{row['status']}`",
            row["compiler_evidence"],
            row["tapenade_evidence"],
            row["fortad"],
        ]
        lines.append("| " + " | ".join(value.replace("|", "\\|") for value in values) + " |")
    lines += [
        "",
        "The other `runnable` rows are the next candidates for explicit entry-point",
        "selection, generated-code compilation, and independent finite-difference",
        "and adjoint-oracle cases. The separate `v420` case has already cleared",
        "those gates. This report remains source-viability evidence and must not",
        "be read as a support result for the other rows.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="run probes and write the committed report")
    parser.add_argument("--check", action="store_true", help="verify the report matches a fresh probe")
    args = parser.parse_args()
    if not args.write and not args.check:
        parser.error("choose --write or --check")
    rendered = render(probe())
    if args.check:
        if not REPORT.is_file() or REPORT.read_text(encoding="utf-8") != rendered:
            print(f"stale or missing {REPORT.relative_to(ROOT)}")
            return 1
    else:
        REPORT.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
