#!/usr/bin/env python3
"""Independent strict-compiler oracle for the invalid lh046 source set."""

from __future__ import annotations

import argparse
import re
import subprocess
import tempfile
from pathlib import Path


STRICT_FLAGS = [
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-fsyntax-only",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-cpp",
]

EXPECTED = {
    "program.f": ("Nonstandard type declaration REAL*16", "Expecting variable in READ statement"),
    "program_d.f": ("Nonstandard type declaration REAL*16", "Expecting variable in READ statement"),
    "program_b.f": ("Nonstandard type declaration REAL*16", "has no IMPLICIT type"),
}


def compile_source(compiler: str, source: Path, work: Path) -> tuple[int, str]:
    completed = subprocess.run(
        [compiler, *STRICT_FLAGS, "-I", str(source.parent), "-J", str(work), str(source)],
        cwd=work,
        capture_output=True,
        text=True,
        check=False,
    )
    return completed.returncode, completed.stdout + completed.stderr


def diagnostic_lines(log: str) -> list[str]:
    return [line.strip() for line in log.splitlines() if re.search(r"(?:Error|Fatal Error):", line)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()

    source_root = args.source_root.resolve()
    sources = [source_root / name for name in EXPECTED]
    if any(not source.is_file() for source in sources):
        raise SystemExit("lh046 source closure is incomplete")

    with tempfile.TemporaryDirectory(prefix="lh046-oracle-") as temporary:
        observations = [compile_source(args.compiler, source, Path(temporary)) for source in sources]

    for source, (status, log) in zip(sources, observations):
        markers = EXPECTED[source.name]
        if status == 0 or any(marker not in log for marker in markers):
            raise SystemExit(f"{source.name} did not reproduce all expected independent diagnostics")
        matched = [marker for marker in markers if marker in log]
        print(f"oracle_{source.name}: expected-refusal status={status} diagnostics={','.join(matched)}")
        for line in diagnostic_lines(log)[:5]:
            print(f"oracle_{source.name}_diagnostic: {line}")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
