#!/usr/bin/env python3
"""Independent finite-domain oracle for the exact lh103 operation sequence.

The upstream routine has uninitialized loop bounds, so this is deliberately a
bounded semantic model, not a repaired or executable port of program.f.
"""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_inventory(source: Path) -> None:
    compact = re.sub(r"\s+", "", source.read_text(encoding="latin-1").lower())
    required = (
        "subroutineh(a,b,c,r)",
        "doi=1,50",
        "b(j)=3.0*b(j)",
        "doi=j,imax",
        "a(i)=5.2*a(i)",
        "b(j)=3.0*b(j)",
        "r=a(j)*b(j)*c(j,j)",
    )
    for fragment in required:
        require(fragment in compact, f"source inventory missing {fragment!r}")
    positions = [compact.find(required[1]), compact.find(required[2])]
    positions.append(compact.find(required[3], positions[-1] + 1))
    positions.append(compact.find(required[4], positions[-1] + 1))
    positions.append(compact.find(required[5], positions[-1] + 1))
    positions.append(compact.find(required[6], positions[-1] + 1))
    require(positions == sorted(positions), "exact loop/update order changed")
    print("oracle_source_inventory: pass")


def primal(a: list[float], b: list[float], c: list[list[float]], *, jmax: int,
           imax: int, ifirst: int, jfirst: int) -> float:
    """Model the finite initialized execution, including Fortran j=jmax+1."""
    for i in range(1, 51):
        a[i] *= 2.0
    for j in range(1, jmax + 1):
        b[j] *= 3.0
    for j in range(1, jmax + 1):
        for i in range(j, imax + 1):
            c[i][j] = a[i] * b[j]
    for i in range(ifirst, imax + 1):
        a[i] *= 5.2
    for j in range(jfirst, jmax + 1):
        b[j] *= 3.0
    j = jmax + 1
    return a[j] * b[j] * c[j][j]


def fixture(a0: float = 1.25, b0: float = 0.75) -> tuple[float, ...]:
    n = 60
    a = [0.0] + [a0 + 0.01 * i for i in range(1, n + 1)]
    b = [0.0] + [b0 - 0.005 * i for i in range(1, n + 1)]
    c = [[0.2 + 0.001 * i + 0.002 * j for j in range(n + 1)] for i in range(n + 1)]
    return (a, b, c)


def value(a0: float, b0: float) -> float:
    a, b, c = fixture(a0, b0)
    return primal(a, b, c, jmax=4, imax=8, ifirst=3, jfirst=2)


def check_jvp() -> None:
    a0, b0 = 1.25, 0.75
    da, db = 0.37, -0.22
    h = 1.0e-6
    numeric = (value(a0 + h * da, b0 + h * db) - value(a0 - h * da, b0 - h * db)) / (2.0 * h)
    # For this fixture, the result uses only the post-loop index j=5.
    # C(5,5) is outside the preceding j=1..jmax writes and remains its
    # initialized fixture value; A(5)=2*5.2*A0(5), while B(5) is unchanged.
    a5, b5 = a0 + 0.05, b0 - 0.025
    c55 = 0.2 + 0.001 * 5 + 0.002 * 5
    analytic = 10.4 * c55 * b5 * da + 10.4 * c55 * a5 * db
    require(math.isclose(numeric, analytic, rel_tol=2.0e-8, abs_tol=2.0e-9),
            f"JVP finite difference mismatch: {numeric} != {analytic}")
    print("oracle_jvp_finite_difference: pass")


def check_vjp() -> None:
    a0, b0 = 1.25, 0.75
    a5, b5 = a0 + 0.05, b0 - 0.025
    c55 = 0.2 + 0.001 * 5 + 0.002 * 5
    grad = (10.4 * c55 * b5, 10.4 * c55 * a5)
    direction = (0.37, -0.22)
    cotangent = -1.3
    left = (cotangent * grad[0]) * direction[0] + (cotangent * grad[1]) * direction[1]
    right = cotangent * (grad[0] * direction[0] + grad[1] * direction[1])
    require(math.isclose(left, right, rel_tol=0.0, abs_tol=1.0e-14),
            f"VJP dot-product identity failed: {left} != {right}")
    print("oracle_vjp_dot_product: pass")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    source = parser.parse_args().source_root.resolve() / "program.f"
    source_inventory(source)
    check_jvp()
    check_vjp()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
