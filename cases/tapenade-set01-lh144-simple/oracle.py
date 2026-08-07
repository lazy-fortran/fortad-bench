#!/usr/bin/env python3
"""Independent arithmetic oracle for nonRegressions/set01/lh144."""
from __future__ import annotations

import math


def primal(x: float, y: float) -> tuple[float, float]:
    a = x * y
    x = a * a
    x = x * x
    return x, 5.0 * y


def jvp(x: float, y: float, dx: float, dy: float) -> tuple[float, float]:
    a = x * y
    da = dx * y + x * dy
    x1 = a * a
    dx1 = 2.0 * a * da
    x2 = x1 * x1
    dx2 = 2.0 * x1 * dx1
    return dx2, 5.0 * dy


def vjp(x: float, y: float, bx: float, by: float) -> tuple[float, float]:
    # x_out = (x*y)^4 and y_out = 5*y.
    dxx = 4.0 * x**3 * y**4
    dxy = 4.0 * x**4 * y**3
    return bx * dxx, bx * dxy + by * 5.0


def main() -> None:
    eps = 1.0e-6
    for x, y in ((0.7, 1.2), (1.3, -0.8), (-0.4, 2.1)):
        fx, fy = primal(x, y)
        for dx, dy in ((1.0, 0.0), (0.0, 1.0), (0.3, -0.7)):
            fd = tuple((a - b) / eps for a, b in zip(
                primal(x + eps * dx, y + eps * dy), (fx, fy)))
            got = jvp(x, y, dx, dy)
            assert max(abs(a - b) for a, b in zip(fd, got)) < 5.0e-4
        gx, gy = vjp(x, y, 0.4, -0.9)
        dx, dy = 0.3, -0.7
        lhs = 0.4 * jvp(x, y, dx, dy)[0] - 0.9 * jvp(x, y, dx, dy)[1]
        rhs = gx * dx + gy * dy
        assert math.isclose(lhs, rhs, rel_tol=2.0e-6, abs_tol=2.0e-6)
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
