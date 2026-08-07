#!/usr/bin/env python3
"""Independent behavioral oracle for the lh095 testliveness computation."""

from __future__ import annotations

import math
from typing import Sequence


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def value(a: float) -> tuple[float, float, float]:
    require(a > 0.0, "oracle inputs must keep log(a) defined")
    b1 = 3.1 + math.log(a)
    b2 = b1**3
    return b1**2, b2, 3.2 + 2.0 * b2


def jvp(a: float, da: float) -> tuple[float, float, float]:
    b1 = 3.1 + math.log(a)
    db1 = da / a
    db2 = 3.0 * b1**2 * db1
    return 2.0 * b1 * db1, db2, 2.0 * db2


def vjp(a: float, seed: Sequence[float]) -> float:
    b1 = 3.1 + math.log(a)
    return (seed[0] * 2.0 * b1 + (seed[1] + 2.0 * seed[2]) * 3.0 * b1**2) / a


def check_case(a: float, da: float, seed: tuple[float, float, float]) -> None:
    h = 1.0e-6
    plus = value(a + h * da)
    minus = value(a - h * da)
    numeric = tuple((p - m) / (2.0 * h) for p, m in zip(plus, minus))
    analytic = jvp(a, da)
    require(all(math.isclose(x, y, rel_tol=3.0e-9, abs_tol=2.0e-9) for x, y in zip(numeric, analytic)), f"JVP finite difference mismatch for a={a}")
    require(math.isclose(sum(s * x for s, x in zip(seed, analytic)), vjp(a, seed) * da, rel_tol=0.0, abs_tol=2.0e-12), f"VJP identity mismatch for a={a}")
    require(all(math.isfinite(x) for x in value(a)), f"non-finite value for a={a}")


def main() -> int:
    cases = ((0.35, -0.2, (0.4, -0.3, 0.8)), (1.0, 0.7, (-0.2, 0.5, -0.6)), (2.75, -1.1, (0.9, 0.1, 0.25)))
    for case in cases:
        check_case(*case)
    print("oracle_cases: 3")
    print("oracle_jvp_finite_difference: pass")
    print("oracle_vjp_adjoint_identity: pass")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
