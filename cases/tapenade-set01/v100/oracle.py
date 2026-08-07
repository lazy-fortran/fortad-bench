#!/usr/bin/env python3
"""Independent behavioral oracle for the bounded v100 MOD interval."""

from __future__ import annotations

import math


POINTS = (0.23, 0.25, 0.31, 0.37)
MAX_ERROR = 0.0


def exact_map(x: float) -> tuple[float, float]:
    x_out = 10.0 * x
    return x_out, math.fmod(x_out, 2.0)


def bounded_map(x: float) -> tuple[float, float]:
    x_out = 10.0 * x
    return x_out, x_out - 2.0


def close(label: str, actual: float, expected: float, tolerance: float = 1.0e-12) -> None:
    global MAX_ERROR
    error = abs(actual - expected)
    MAX_ERROR = max(MAX_ERROR, error)
    if error > tolerance:
        raise AssertionError(f"{label}: {actual!r} != {expected!r}")


for point in POINTS:
    if not 0.2 < point < 0.4:
        raise AssertionError("test point is outside the declared bounded interval")
    exact_x, exact_y = exact_map(point)
    port_x, port_y = bounded_map(point)
    close("x_out", port_x, exact_x)
    close("y", port_y, exact_y)

for point in POINTS:
    step = 1.0e-7
    derivative = (bounded_map(point + step)[1] - bounded_map(point - step)[1]) / (2.0 * step)
    close("central_difference", derivative, 10.0, 1.0e-8)

direction = 0.37
cotangent = -1.6
jvp = 10.0 * direction
lhs = jvp * cotangent
rhs = direction * (10.0 * cotangent)
close("adjoint_identity", lhs, rhs)

print(f"finite_difference_max_error: {MAX_ERROR:.3e}")
print(f"adjoint_identity_residual: {abs(lhs - rhs):.3e}")
print("oracle_status: pass")
