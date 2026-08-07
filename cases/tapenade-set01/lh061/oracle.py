#!/usr/bin/env python3
"""Independent strict-compiler oracle for the lh061 callback boundary."""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path


STRICT_FLAGS = [
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
]
PASS_SOURCES = ("program.f", "program_p.f", "program_d.f", "program_b.f")


def compile_source(compiler: str, source: Path, work: Path) -> tuple[int, str]:
    completed = subprocess.run(
        [compiler, *STRICT_FLAGS, "-c", str(source), "-o", str(work / (source.stem + ".o"))],
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
    expected = [source_root / name for name in (*PASS_SOURCES, "program_dv.f")]
    if any(not source.is_file() for source in expected):
        raise SystemExit("lh061 source closure is incomplete")

    with tempfile.TemporaryDirectory(prefix="lh061-compiler-oracle-") as temporary:
        work = Path(temporary)
        observations = {
            name: compile_source(args.compiler, source_root / name, work)
            for name in (*PASS_SOURCES, "program_dv.f")
        }

    for name in PASS_SOURCES:
        status, log = observations[name]
        if status != 0:
            raise SystemExit(f"{name} unexpectedly refused strict compilation:\n{log}")
        print(f"oracle_{name}: pass")

    status, log = observations["program_dv.f"]
    if status == 0 or "Cannot open included file" not in log:
        raise SystemExit("program_dv.f did not reproduce the missing DIFFSIZES.inc refusal")
    print(f"oracle_program_dv.f: expected-refusal status={status} missing-DIFFSIZES.inc")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
