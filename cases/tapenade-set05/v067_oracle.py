#!/usr/bin/env python3
"""Independent source/compiler oracle for the v067 modern-Fortran boundary."""

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
LEGACY = (
    "-std=legacy",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fno-lto",
)


def compile_one(compiler: str, source: Path, module_dir: Path, flags: tuple[str, ...]) -> tuple[int, str]:
    completed = subprocess.run(
        [compiler, *flags, f"-I{source.parent}", f"-J{module_dir}", "-c", str(source), "-o", str(module_dir / "source.o")],
        capture_output=True,
        text=True,
        check=False,
    )
    return completed.returncode, (completed.stdout or "") + (completed.stderr or "")


def run(source_dir: Path, compiler: str = "gfortran") -> None:
    primal = (source_dir / "program.f90").read_text(encoding="utf-8")
    stored_forward = (source_dir / "program_d.f90").read_text(encoding="utf-8")
    stored_primal = (source_dir / "program_p.f90").read_text(encoding="utf-8")
    normalized = "".join(primal.lower().split())
    for fragment in ("real*8::mb3", "real*8::m3", "callfunc(mb3)", "subroutines(mb1,mb2,mb3)"):
        if fragment not in normalized:
            raise AssertionError(f"missing v067 source invariant: {fragment}")
    for text, name in ((stored_forward, "program_d.f90"), (stored_primal, "program_p.f90")):
        if "real*8" not in "".join(text.lower().split()):
            raise AssertionError(f"missing legacy REAL*8 invariant in {name}")

    sources = [source_dir / name for name in ("program.f90", "program_d.f90", "program_p.f90")]
    with tempfile.TemporaryDirectory(prefix="fortad-v067-oracle-") as directory:
        scratch = Path(directory)
        strict_statuses = []
        legacy_statuses = []
        for source in sources:
            strict_module = scratch / f"strict-{source.stem}"
            legacy_module = scratch / f"legacy-{source.stem}"
            strict_module.mkdir()
            legacy_module.mkdir()
            strict_status, strict_output = compile_one(compiler, source, strict_module, STRICT)
            legacy_status, legacy_output = compile_one(compiler, source, legacy_module, LEGACY)
            if strict_status == 0:
                raise AssertionError(f"strict v067 source unexpectedly compiled: {source.name}")
            if "nonstandard type declaration real*8" not in strict_output.lower():
                raise AssertionError(f"strict compiler did not preserve the REAL*8 boundary for {source.name}:\n{strict_output}")
            if legacy_status != 0:
                raise AssertionError(f"legacy v067 control failed for {source.name}:\n{legacy_output}")
            strict_statuses.append(strict_status)
            legacy_statuses.append(legacy_status)
    print("oracle_source_invariants: legacy-real-star-8-and-generic-mb3-call")
    print(f"oracle_strict_compiler_checks: {len(strict_statuses)}")
    print(f"oracle_legacy_compiler_checks: {len(legacy_statuses)}")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else "gfortran")
