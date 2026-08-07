#!/usr/bin/env python3
"""Independent compiler and index-domain oracle for Tapenade set01/lh087."""

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
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
]
PASS_SOURCES = ("program.f", "program_p.f", "program_d.f", "program_b.f")


def compile_source(compiler: str, source: Path, work: Path, *, extra: list[str] = ()) -> tuple[int, str]:
    completed = subprocess.run(
        [compiler, *STRICT_FLAGS, *extra, "-c", str(source), "-o", str(work / f"{source.name}.o")],
        cwd=work,
        capture_output=True,
        text=True,
        check=False,
    )
    return completed.returncode, completed.stdout + completed.stderr


def check_source_index_domains(source: Path) -> None:
    text = source.read_text(encoding="latin-1").lower()
    compact = re.sub(r"\s+", "", text)
    required = (
        "doubleprecisionphase(10),number(5),sigma(10)",
        "doubleprecisionpp(10,20),pp1(10,20)",
        "doj=1,20",
        "phase(j)",
        "pp1(j,i)",
    )
    if any(fragment not in compact for fragment in required):
        raise SystemExit("lh087 source does not match the recorded loop/index boundary")
    if "phase(10),number(5),sigma(10)" not in compact:
        raise SystemExit("lh087 phase/sigma bounds are not the recorded extent")
    print("oracle_source_index_domain: expected-refusal j=11..20 exceeds phase(10) and pp1 first extent")


def check_fortad_forward(compiler: str, generated: Path) -> None:
    text = generated.read_text(encoding="utf-8").lower()
    if "fad_c1 = phase(j) * number(k)" not in text:
        raise SystemExit("FortAD forward artifact no longer exposes the observed pre-loop expression")
    if not re.search(r"fad_c1\s*=.*\n\s*do i\s*=\s*1\s*,\s*10", text):
        raise SystemExit("FortAD forward artifact no longer has the observed pre-loop evaluation")
    with tempfile.TemporaryDirectory(prefix="lh087-forward-oracle-") as temporary:
        work = Path(temporary)
        status, log = compile_source(compiler, generated, work, extra=["-ffree-form", "-Werror=uninitialized"])
    if status == 0 or "uninitialized" not in log.lower():
        raise SystemExit("FortAD forward artifact did not reproduce the independent uninitialized-index refusal")
    print(f"oracle_fortad_forward: expected-refusal status={status} uninitialized-loop-indices")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("--compiler", default="gfortran")
    parser.add_argument("--fortad-forward", type=Path)
    args = parser.parse_args()
    source_root = args.source_root.resolve()
    sources = [source_root / name for name in (*PASS_SOURCES, "program_dv.f")]
    if any(not source.is_file() for source in sources):
        raise SystemExit("lh087 source closure is incomplete")

    with tempfile.TemporaryDirectory(prefix="lh087-compiler-oracle-") as temporary:
        work = Path(temporary)
        observations = {
            source.name: compile_source(args.compiler, source, work)
            for source in sources
        }
    for name in PASS_SOURCES:
        status, log = observations[name]
        if status != 0:
            raise SystemExit(f"{name} unexpectedly refused strict compilation:\n{log}")
        print(f"oracle_{name}: pass")
    status, log = observations["program_dv.f"]
    if status == 0 or "cannot open included file" not in log.lower():
        raise SystemExit("program_dv.f did not reproduce the missing DIFFSIZES.inc refusal")
    print(f"oracle_program_dv.f: expected-refusal status={status} missing-DIFFSIZES.inc")

    check_source_index_domains(source_root / "program.f")
    if args.fortad_forward is not None:
        check_fortad_forward(args.compiler, args.fortad_forward.resolve())
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
