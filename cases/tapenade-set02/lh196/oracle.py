#!/usr/bin/env python3
"""Independent polygon-cost primal, JVP, VJP, and compiler-free oracle."""

from __future__ import annotations

import math
import sys
from pathlib import Path
from typing import Sequence


def source_inventory(source: Path) -> None:
    normalized = "".join(source.read_text(encoding="utf-8").lower().split())
    fragments = (
        "programmain",
        "functionpolycost(x,y,ns)",
        "functionpolysurf(x,y,ns)",
        "functionpolyperim(x,y,ns)",
        "subroutineincrsqrt(pp,dxx,dyy)",
        "callincrsqrt(polyperim,dx,dy)",
        "real*8",
        "sqrt(xx2+yy2)",
    )
    for fragment in fragments:
        if fragment not in normalized:
            raise AssertionError(f"exact source is missing {fragment}")


def polygon_value(x: Sequence[float], y: Sequence[float]) -> float:
    perimeter = 0.0
    area = 0.0
    for cp in range(len(x)):
        pp = (cp - 1) % len(x)
        dx = x[cp] - x[pp]
        dy = y[cp] - y[pp]
        perimeter += math.hypot(dx, dy)
        area += (x[pp] * y[cp] - x[cp] * y[pp]) / 2.0
    return perimeter * perimeter / area


def polygon_jvp(
    x: Sequence[float], y: Sequence[float], xd: Sequence[float], yd: Sequence[float]
) -> float:
    perimeter = 0.0
    dperimeter = 0.0
    area = 0.0
    darea = 0.0
    for cp in range(len(x)):
        pp = (cp - 1) % len(x)
        dx = x[cp] - x[pp]
        dy = y[cp] - y[pp]
        dxx = xd[cp] - xd[pp]
        dyy = yd[cp] - yd[pp]
        edge = math.hypot(dx, dy)
        perimeter += edge
        dperimeter += (dx * dxx + dy * dyy) / edge
        area += (x[pp] * y[cp] - x[cp] * y[pp]) / 2.0
        darea += (
            xd[pp] * y[cp]
            + x[pp] * yd[cp]
            - xd[cp] * y[pp]
            - x[cp] * yd[pp]
        ) / 2.0
    return 2.0 * perimeter * dperimeter / area - perimeter**2 * darea / area**2


def gradient(x: Sequence[float], y: Sequence[float]) -> tuple[float, ...]:
    values: list[float] = []
    for index in range(2 * len(x)):
        xd = [0.0] * len(x)
        yd = [0.0] * len(y)
        if index < len(x):
            xd[index] = 1.0
        else:
            yd[index - len(x)] = 1.0
        values.append(polygon_jvp(x, y, xd, yd))
    return tuple(values)


def run(source: Path) -> None:
    source_inventory(source)
    cases = (
        ((0.0, 2.0, 2.0, 1.0, -3.0), (0.0, 0.0, 3.0, 6.0, 3.0)),
        ((0.2, 2.1, 1.8, 1.2, -2.7), (-0.1, 0.3, 3.2, 5.7, 2.8)),
        ((-0.5, 1.4, 2.7, 0.4, -2.4), (0.4, -0.2, 2.6, 6.4, 2.5)),
    )
    direction = (0.13, -0.07, 0.11, -0.19, 0.05, -0.04, 0.16, -0.09, 0.12, -0.08)
    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for x, y in cases:
        tangent = polygon_jvp(x, y, direction[:5], direction[5:])
        step = 1.0e-6
        plus_x = tuple(a + step * b for a, b in zip(x, direction[:5]))
        plus_y = tuple(a + step * b for a, b in zip(y, direction[5:]))
        minus_x = tuple(a - step * b for a, b in zip(x, direction[:5]))
        minus_y = tuple(a - step * b for a, b in zip(y, direction[5:]))
        finite_difference = (
            polygon_value(plus_x, plus_y) - polygon_value(minus_x, minus_y)
        ) / (2.0 * step)
        max_fd_error = max(max_fd_error, abs(tangent - finite_difference))

        seed = 0.73
        grad = tuple(seed * item for item in gradient(x, y))
        dot_input = sum(a * b for a, b in zip(grad, direction))
        max_adjoint_error = max(max_adjoint_error, abs(dot_input - seed * tangent))
        if not math.isfinite(polygon_value(x, y)):
            raise AssertionError("non-finite polygon cost")

    if max_fd_error > 2.0e-7 or max_adjoint_error > 2.0e-12:
        raise AssertionError(
            f"polygon derivative mismatch: fd={max_fd_error} adjoint={max_adjoint_error}"
        )
    print("oracle_semantics: polygon perimeter-squared over signed area")
    print("oracle_behavioral_cases: 3")
    print(f"finite_difference_max_error: {max_fd_error:.6e}")
    print(f"adjoint_identity_max_error: {max_adjoint_error:.6e}")
    print(f"primal_reference_cost: {polygon_value(*cases[0]):.16e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).with_name("program.f"))
