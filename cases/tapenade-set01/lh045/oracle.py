#!/usr/bin/env python3
"""Independent closed-form and finite-difference oracle for bounded lh045."""

from __future__ import annotations

import argparse
import math


def primal(x: float, y: float, w4: float, v2: float) -> tuple[float, float, float]:
    v1 = x * v2 - 105.0
    return (y - 10.0 if x > y else x, 2.0 * (v1 + 6.0) + w4, v1 * v2)


def jvp(x: float, y: float, w4: float, v2: float, d: tuple[float, ...]) -> tuple[float, ...]:
    xd, yd, w4d, v2d = d
    v1d = xd * v2 + x * v2d
    xod = yd if x > y else xd
    return xod, 2.0 * v1d + w4d, v1d * v2 + (x * v2 - 105.0) * v2d


def vjp(x: float, y: float, w4: float, v2: float, seed: tuple[float, ...]) -> tuple[float, ...]:
    xs, zs, ws = seed
    branch_x = 0.0 if x > y else 1.0
    return (
        branch_x * xs + 2.0 * v2 * zs + v2 * v2 * ws,
        (1.0 - branch_x) * xs,
        zs,
        2.0 * x * zs + (2.0 * x * v2 - 105.0) * ws,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("_source_root", nargs="?")
    args = parser.parse_args()
    del args
    d = (0.31, -0.22, 0.17, -0.13)
    seed = (-0.41, 0.73, -0.29)
    for x, y in ((2.4, 1.1), (0.7, 1.1)):
        w4, v2 = -0.35, 1.25
        analytical = jvp(x, y, w4, v2, d)
        h = 1.0e-6
        plus = primal(x + h*d[0], y + h*d[1], w4 + h*d[2], v2 + h*d[3])
        minus = primal(x - h*d[0], y - h*d[1], w4 - h*d[2], v2 - h*d[3])
        finite = tuple((a - b) / (2.0 * h) for a, b in zip(plus, minus))
        if max(abs(a - b) for a, b in zip(analytical, finite)) > 2.0e-7:
            raise SystemExit("finite-difference mismatch")
        adjoint = vjp(x, y, w4, v2, seed)
        lhs = sum(a * b for a, b in zip(seed, analytical))
        rhs = sum(a * b for a, b in zip(adjoint, d))
        if not math.isclose(lhs, rhs, rel_tol=2.0e-13, abs_tol=2.0e-13):
            raise SystemExit("adjoint identity mismatch")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
