#!/usr/bin/env python3
"""Independent source-validity oracle for the invalid v066 closure."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


STRICT = (
    "-std=f2018",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fno-lto",
)


def run(source_dir: Path, compiler: str = "gfortran") -> None:
    primal = (source_dir / "program.f90").read_text(encoding="utf-8")
    stored = (source_dir / "program_d.f90").read_text(encoding="utf-8")
    normalized = "".join(primal.lower().split())
    for fragment in (
        "moduleprocedurefunc1,func2,func3",
        "real,dimension(10,40)::mb",
        "real,dimension(10,60)::mb",
        "real,dimension(10,50)::mb3",
        "real,dimension(10,70)::mb4",
        "callfunc(mb3)",
        "callfunc(mb4)",
    ):
        if fragment not in normalized:
            raise AssertionError(f"missing v066 source invariant: {fragment}")
    stored_normalized = "".join(stored.lower().split())
    for fragment in ("moduleprocedurefunc1,func2,func3", "moduleprocedurefunc1_d,func2_d,func3_d"):
        if fragment not in stored_normalized:
            raise AssertionError(f"missing stored v066 invariant: {fragment}")

    with tempfile.TemporaryDirectory(prefix="fortad-v066-oracle-") as directory:
        scratch = Path(directory)
        for source in (source_dir / "program.f90", source_dir / "program_d.f90"):
            completed = subprocess.run(
                [compiler, *STRICT, f"-I{source_dir}", f"-J{scratch}", "-c", str(source), "-o", str(scratch / "source.o")],
                capture_output=True,
                text=True,
                check=False,
            )
            if completed.returncode == 0:
                raise AssertionError(f"invalid v066 source unexpectedly compiled: {source.name}")
            if "ambiguous interfaces in generic interface 'func'" not in completed.stderr.lower():
                raise AssertionError(f"compiler did not preserve the generic-interface boundary for {source.name}:\n{completed.stderr}")
    print("oracle_source_invariants: generic-overload-shape-and-call-mismatch")
    print("oracle_compiler_checks: 2")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else "gfortran")
