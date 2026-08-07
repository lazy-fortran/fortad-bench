#!/usr/bin/env python3
"""Independent strict-compiler oracle for the lh021 source boundary."""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path


STRICT_FLAGS = ["-std=f2018", "-pedantic-errors", "-ffixed-line-length-none"]


def compile_source(compiler: str, source: Path, work: Path) -> tuple[int, str]:
    object_file = work / (source.stem + ".o")
    completed = subprocess.run(
        [compiler, *STRICT_FLAGS, "-c", str(source), "-o", str(object_file)],
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

    source_root = args.source_root
    primal = source_root / "program.f"
    tangent = source_root / "program_d.f"
    reverse = source_root / "program_b.f"
    with tempfile.TemporaryDirectory(prefix="lh021-oracle-") as temporary:
        work = Path(temporary)
        primal_status, primal_log = compile_source(args.compiler, primal, work)
        tangent_status, tangent_log = compile_source(args.compiler, tangent, work)
        reverse_status, reverse_log = compile_source(args.compiler, reverse, work)

    if primal_status != 0 or tangent_status != 0:
        raise SystemExit("lh021 strict primal/tangent oracle unexpectedly failed")
    if reverse_status == 0 or "INTEGER*4" not in reverse_log:
        raise SystemExit("lh021 strict reverse oracle lost the expected INTEGER*4 refusal")

    print("oracle_exact_primal: pass")
    print("oracle_stored_tangent: pass")
    print("oracle_stored_reverse: expected-refusal INTEGER*4")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
