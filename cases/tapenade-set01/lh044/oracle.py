#!/usr/bin/env python3
"""Independent strict-compiler oracle for the invalid lh044 source."""

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
]
EXPECTED_MARKER = "DUMMY attribute conflicts with INTRINSIC attribute"
SOURCES = ("program.f", "program_p.f", "program_d.f", "program_b.f", "program_dv.f")


def compile_source(compiler: str, source: Path, include_dir: Path, work: Path) -> tuple[int, str]:
    completed = subprocess.run(
        [
            compiler,
            *STRICT_FLAGS,
            "-I",
            str(include_dir),
            "-J",
            str(work),
            str(source),
        ],
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
    sources = [source_root / name for name in SOURCES]
    if any(not source.is_file() for source in sources):
        raise SystemExit("lh044 source closure is incomplete")

    nonregressions = source_root.parents[1]
    with tempfile.TemporaryDirectory(prefix="lh044-oracle-") as temporary:
        work = Path(temporary)
        include = work / "include"
        include.mkdir()
        (include / "DIFFSIZES.inc").symlink_to(nonregressions / "DIFFSIZES.f")
        observations = [
            compile_source(args.compiler, source, include, work) for source in sources
        ]

    for source, (status, log) in zip(sources, observations):
        if status == 0 or EXPECTED_MARKER not in log:
            raise SystemExit(
                f"{source.name} did not reproduce the FX1 intrinsic/dummy diagnostic"
            )
        print(f"oracle_{source.name}: expected-refusal status={status} FX1-intrinsic-dummy")

    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
