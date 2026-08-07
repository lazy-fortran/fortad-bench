#!/usr/bin/env python3
"""Independent source/compiler oracle for the invalid v069 closure."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

STRICT = ("-std=f2018", "-ffree-form", "-ffree-line-length-none", "-pedantic-errors",
          "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto")
LEGACY = ("-std=legacy", "-ffree-form", "-ffree-line-length-none", "-pedantic-errors",
          "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto")


def compile_one(compiler: str, source: Path, module_dir: Path,
                flags: tuple[str, ...]) -> tuple[int, str]:
    module_dir.mkdir(parents=True)
    completed = subprocess.run(
        [compiler, *flags, f"-I{source.parent}", f"-J{module_dir}", "-c",
         str(source), "-o", str(module_dir / "source.o")],
        capture_output=True, text=True, check=False)
    return completed.returncode, (completed.stdout or "") + (completed.stderr or "")


def run(source_dir: Path, compiler: str = "gfortran") -> None:
    primal = (source_dir / "program.f90").read_text(encoding="utf-8")
    stored = (source_dir / "program_d.f90").read_text(encoding="utf-8")
    message = (source_dir / "program_d.msg").read_text(encoding="utf-8")
    normalized = "".join(primal.lower().split())
    for fragment in ("elementalsubroutinefunc2(mb)", "elementalsubroutinefunc3(mb)",
                     "print*,'func2'", "print*,'func3'", "real*8::mb",
                     "callfunc(mb3)", "callfunc(mb3(1))"):
        if fragment not in normalized:
            raise AssertionError(f"missing v069 source invariant: {fragment}")
    stored_normalized = "".join(stored.lower().split())
    for fragment in ("elementalsubroutinefunc2(mb)", "elementalsubroutinefunc3(mb)",
                     "real*8::mb", "callfunc_d(mb3,mb3d)"):
        if fragment not in stored_normalized:
            raise AssertionError(f"missing stored v069 invariant: {fragment}")
    if "(tc30)typemismatchinargument1ofprocedurefunc" not in "".join(message.lower().split()):
        raise AssertionError("stored v069 message lost the TC30 generic-call mismatch")

    with tempfile.TemporaryDirectory(prefix="fortad-v069-oracle-") as directory:
        scratch = Path(directory)
        checks = 0
        for source in (source_dir / "program.f90", source_dir / "program_d.f90"):
            for flavor, flags in (("strict", STRICT), ("legacy", LEGACY)):
                status, output = compile_one(compiler, source,
                                             scratch / f"{source.stem}-{flavor}", flags)
                if status == 0:
                    raise AssertionError(f"invalid v069 source unexpectedly compiled: {source.name} ({flavor})")
                if "print statement at" not in output.lower() or "pure procedure" not in output.lower():
                    raise AssertionError(f"compiler lost elemental/pure PRINT boundary for {source.name} ({flavor}):\n{output}")
                checks += 1
    print("oracle_source_invariants: elemental-pure-print-real8-and-generic-call")
    print(f"oracle_compiler_checks: {checks}")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else "gfortran")
