#!/usr/bin/env python3
"""Independent compiler oracle for the invalid upstream lh036 row."""

from __future__ import annotations

import argparse
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
EXPECTED_MARKER = "The function result on the lhs of the assignment"


def compile_source(compiler: str, source: Path, work: Path) -> tuple[int, str]:
    completed = subprocess.run(
        [compiler, *STRICT_FLAGS, "-I", str(source.parent), "-J", str(work), str(source)],
        cwd=work,
        capture_output=True,
        text=True,
        check=False,
    )
    return completed.returncode, completed.stdout + completed.stderr


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()

    source_root = args.source_root.resolve()
    sources = [source_root / name for name in ("program.f", "program_d.f", "program_p.f")]
    if any(not source.is_file() for source in sources):
        raise SystemExit("lh036 source closure is incomplete")

    with tempfile.TemporaryDirectory(prefix="lh036-oracle-") as temporary:
        work = Path(temporary)
        observations = [compile_source(args.compiler, source, work) for source in sources]

    for source, (status, log) in zip(sources, observations):
        if status == 0 or EXPECTED_MARKER not in log:
            raise SystemExit(
                f"{source.name} did not reproduce the expected malformed ZE diagnostic"
            )

    for source, (status, _) in zip(sources, observations):
        print(f"oracle_{source.name}: expected-refusal status={status} ZE-lhs")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
