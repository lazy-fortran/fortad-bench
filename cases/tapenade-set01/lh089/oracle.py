#!/usr/bin/env python3
"""Independent semantic oracle for Tapenade set01/lh089."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_inventory(source: Path) -> None:
    text = source.read_text(encoding="latin-1").lower()
    compact = re.sub(r"\s+", "", text)
    required = (
        "subroutinepushpop(a,b)",
        "real*8a,b",
        "callpushreal8(a)",
        "a=a*b",
        "b=b+a",
        "callpopreal8(a)",
        "b=a/b",
    )
    for fragment in required:
        require(fragment in compact, f"lh089 source is missing exact operation {fragment!r}")
    positions = [compact.index(fragment) for fragment in required[2:]]
    require(positions == sorted(positions), "lh089 push/pop operation order changed")
    print("oracle_source_inventory: pass")


def pushpop(a: float, b: float) -> tuple[float, float]:
    """Model the exact scalar state transition, including the hidden stack."""
    adstack = [a]
    a = a * b
    b = b + a
    a = adstack.pop()
    b = a / b
    return a, b


def jacobian(a: float, b: float) -> tuple[tuple[float, float], tuple[float, float]]:
    return ((1.0, 0.0), (1.0 / (b * (1.0 + a)**2),
                           -a / (b**2 * (1.0 + a))))


def check_semantics() -> None:
    a, b = pushpop(2.0, 3.0)
    require(math.isclose(a, 2.0, rel_tol=0.0, abs_tol=1.0e-14), "pushpop restored a incorrectly")
    require(math.isclose(b, 2.0 / 9.0, rel_tol=0.0, abs_tol=1.0e-14), "pushpop final b is incorrect")
    print("oracle_pushpop_state_machine: pass")


def check_jvp_and_finite_difference() -> None:
    a, b = 2.0, 3.0
    da, db = 0.25, -0.4
    matrix = jacobian(a, b)
    jvp = (matrix[0][0] * da + matrix[0][1] * db,
           matrix[1][0] * da + matrix[1][1] * db)
    h = 1.0e-6
    plus = pushpop(a + h * da, b + h * db)
    minus = pushpop(a - h * da, b - h * db)
    finite_difference = tuple((p - m) / (2.0 * h) for p, m in zip(plus, minus))
    for analytic, numeric in zip(jvp, finite_difference):
        require(math.isclose(analytic, numeric, rel_tol=2.0e-8, abs_tol=2.0e-10),
                f"JVP disagrees with central difference: {analytic} != {numeric}")
    print("oracle_jvp_finite_difference: pass")


def check_vjp_adjoint_identity() -> None:
    a, b = 2.0, 3.0
    da, db = 0.25, -0.4
    ya, yb = 0.7, -1.1
    matrix = jacobian(a, b)
    gradient = (
        matrix[0][0] * ya + matrix[1][0] * yb,
        matrix[0][1] * ya + matrix[1][1] * yb,
    )
    left = gradient[0] * da + gradient[1] * db
    right = ya * (matrix[0][0] * da + matrix[0][1] * db) \
        + yb * (matrix[1][0] * da + matrix[1][1] * db)
    require(math.isclose(left, right, rel_tol=0.0, abs_tol=1.0e-14),
            f"VJP adjoint identity failed: {left} != {right}")
    require(math.isclose(left, 0.1322222222222222, rel_tol=0.0, abs_tol=1.0e-14),
            "VJP identity did not use the expected exact point")
    print("oracle_vjp_adjoint_identity: pass")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    source_root = args.source_root.resolve()
    source_inventory(source_root / "program.f")
    check_semantics()
    check_jvp_and_finite_difference()
    check_vjp_adjoint_identity()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
