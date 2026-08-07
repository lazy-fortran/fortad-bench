#!/usr/bin/env python3
"""Independent compiler and numerical oracle for the lh037 boundary."""

from __future__ import annotations

import argparse
import math
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


def compile_source(compiler: str, source: Path, work: Path) -> tuple[int, str]:
    completed = subprocess.run(
        [compiler, *STRICT_FLAGS, "-I", str(source.parent), "-J", str(work), str(source)],
        cwd=work,
        capture_output=True,
        text=True,
        check=False,
    )
    return completed.returncode, completed.stdout + completed.stderr


def value(a0: float, b0: float, c0: float) -> tuple[float, float, float]:
    a1 = a0 + b0
    b1 = b0 - c0
    a2 = a1 + 25.5
    return 8.0 * a2, b1, 2.0 * a2 * b1


def jacobian(a0: float, b0: float, c0: float) -> tuple[tuple[float, ...], ...]:
    a1 = a0 + b0
    b1 = b0 - c0
    a2 = a1 + 25.5
    return ((8.0, 8.0, 0.0), (0.0, 1.0, -1.0), (2.0 * b1, 2.0 * (b1 + a2), -2.0 * a2))


def run_numeric_oracle() -> None:
    point = (1.25, 10.75, 1.5)
    direction = (-0.3, 0.2, 0.4)
    output_seed = (0.7, -0.2, 0.5)
    matrix = jacobian(*point)
    jvp = tuple(sum(row[j] * direction[j] for j in range(3)) for row in matrix)
    vjp = tuple(sum(matrix[i][j] * output_seed[i] for i in range(3)) for j in range(3))
    hand_direction = sum(output_seed[i] * jvp[i] for i in range(3))
    adjoint_direction = sum(vjp[j] * direction[j] for j in range(3))
    if not math.isfinite(hand_direction) or abs(hand_direction - adjoint_direction) > 1.0e-12:
        raise SystemExit("adjoint identity failed")

    errors = []
    for step in (1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5):
        plus = value(*(point[i] + step * direction[i] for i in range(3)))
        minus = value(*(point[i] - step * direction[i] for i in range(3)))
        finite_difference = tuple((plus[i] - minus[i]) / (2.0 * step) for i in range(3))
        errors.append(max(abs(finite_difference[i] - jvp[i]) for i in range(3)))
    if min(errors) > 2.0e-9:
        raise SystemExit(f"finite-difference oracle failed: {errors}")
    print("numeric_hand_jvp: pass")
    print("numeric_hand_vjp: pass")
    print("finite_difference: pass")
    print("adjoint_identity: pass")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()
    source_root = args.source_root.resolve()
    expected = {
        "program.f": ("Deleted feature: ASSIGN statement",),
        "program_b.f": ("Deleted feature: ASSIGN statement",),
        "program_d.f": ("Deleted feature: ASSIGN statement",),
        "program_p.f": ("Deleted feature: ASSIGN statement",),
        "program_dv.f": ("Cannot open included file",),
    }
    with tempfile.TemporaryDirectory(prefix="lh037-oracle-") as temporary:
        work = Path(temporary)
        for name, markers in expected.items():
            source = source_root / name
            if not source.is_file():
                raise SystemExit(f"missing exact source: {source}")
            status, log = compile_source(args.compiler, source, work)
            if status == 0 or any(marker not in log for marker in markers):
                raise SystemExit(f"{name} did not reproduce its expected strict diagnostic")
            diagnostic = re.search(r"(?:Error|Fatal Error): .*", log)
            print(f"oracle_{name}: expected-refusal status={status} diagnostic={diagnostic.group(0) if diagnostic else 'present'}")
    run_numeric_oracle()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
