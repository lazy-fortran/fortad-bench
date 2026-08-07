#!/usr/bin/env python3
"""Independent oracle for the exact lighthouse equations."""
from __future__ import annotations

import math


def primal(x: tuple[float, float, float, float]) -> tuple[float, float]:
    x1, x2, x3, x4 = x
    t = math.tan(x3 * x4)
    q = x2 - t
    r = x1 * t / q
    return r, r * x2


def main() -> None:
    eps = 1.0e-7
    points = ((3.7, 0.7, 0.5, 0.5), (2.1, 1.4, 0.2, 0.9), (1.2, 2.0, -0.3, 0.4))
    directions = ((1.0, 0.0, 0.0, 0.0), (0.0, 1.0, -0.2, 0.3))
    for x in points:
        base = primal(x)
        for d in directions:
            perturbed = primal(tuple(a + eps * b for a, b in zip(x, d)))
            fd = tuple((a - b) / eps for a, b in zip(perturbed, base))
            x1, x2, x3, x4 = x
            dx1, dx2, dx3, dx4 = d
            u = x3 * x4
            du = dx3 * x4 + x3 * dx4
            t = math.tan(u)
            dt = (1.0 + t * t) * du
            q = x2 - t
            dq = dx2 - dt
            r = x1 * t / q
            dr = (dx1 * t + x1 * dt) / q - x1 * t * dq / (q * q)
            hand = (dr, dr * x2 + r * dx2)
            assert max(abs(a - b) for a, b in zip(fd, hand)) < 5.0e-5
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
