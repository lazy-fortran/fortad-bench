#!/usr/bin/env python3
"""Independent hand tangent, finite-difference, and adjoint checks for lh047."""

from __future__ import annotations

import math
from typing import Sequence


NAMES = ("u", "z", "t", "x1", "x8", "x9", "x10", "x11", "y", "v")


def value(q: Sequence[float]) -> tuple[float, ...]:
    u, z, t, _x1, x8, x9, x10, x11, y, v = q
    x1 = y * u + t
    u = 0.0
    u = u * y + x8 * z
    y = z + v * y
    v = u * x10
    t = t + x1 * z + 3.0 * v
    u = u * y + x9 * z
    y = z + v * y
    v = u * x11
    t = t + x1 * z + 3.0 * u
    return (u, z, t, x1, x8, x9, x10, x11, y, v)


def hand_jvp(q: Sequence[float], dq: Sequence[float]) -> tuple[float, ...]:
    u, z, t, _x1, x8, x9, x10, x11, y, v = q
    du, dz, dt, _dx1, dx8, dx9, dx10, dx11, dy, dv = dq

    x1 = y * u + t
    dx1 = dy * u + y * du + dt
    u = 0.0
    du = 0.0

    u0 = u * y + x8 * z
    du0 = du * y + u * dy + dx8 * z + x8 * dz
    y0 = z + v * y
    dy0 = dz + dv * y + v * dy
    v0 = u0 * x10
    dv0 = du0 * x10 + u0 * dx10
    t0 = t + x1 * z + 3.0 * v0
    dt0 = dt + dx1 * z + x1 * dz + 3.0 * dv0

    u1 = u0 * y0 + x9 * z
    du1 = du0 * y0 + u0 * dy0 + dx9 * z + x9 * dz
    y1 = z + v0 * y0
    dy1 = dz + dv0 * y0 + v0 * dy0
    v1 = u1 * x11
    dv1 = du1 * x11 + u1 * dx11
    t1 = t0 + x1 * z + 3.0 * u1
    dt1 = dt0 + dx1 * z + x1 * dz + 3.0 * du1
    return (du1, dz, dt1, dx1, dx8, dx9, dx10, dx11, dy1, dv1)


def jacobian(q: Sequence[float]) -> list[tuple[float, ...]]:
    columns = []
    for i in range(len(NAMES)):
        dq = [0.0] * len(NAMES)
        dq[i] = 1.0
        columns.append(hand_jvp(q, dq))
    return [tuple(column[row] for column in columns) for row in range(len(NAMES))]


def main() -> None:
    fd_errors: list[float] = []
    adjoint_residuals: list[float] = []
    for q in (
        (0.7, 1.1, 2.0, -99.0, 0.5, 0.6, 1.3, 1.4, 0.9, 0.2),
        (-0.25, 0.8, -1.4, 42.0, -0.7, 1.2, 0.4, -0.9, 1.6, -0.3),
    ):
        direction = tuple(
            (i + 1) * 0.07 * (-1.0 if i % 2 else 1.0)
            for i in range(len(NAMES))
        )
        hand = hand_jvp(q, direction)
        for step in (1.0e-3, 1.0e-4, 1.0e-5):
            plus = tuple(a + step * b for a, b in zip(q, direction))
            minus = tuple(a - step * b for a, b in zip(q, direction))
            finite_difference = tuple(
                (a - b) / (2.0 * step) for a, b in zip(value(plus), value(minus))
            )
            fd_errors.extend(abs(a - b) for a, b in zip(finite_difference, hand))

        seed = tuple(0.11 * (i + 2) for i in range(len(NAMES)))
        matrix = jacobian(q)
        vjp = tuple(sum(matrix[row][col] * seed[row] for row in range(len(NAMES)))
                    for col in range(len(NAMES)))
        lhs = sum(a * b for a, b in zip(seed, hand))
        rhs = sum(a * b for a, b in zip(vjp, direction))
        adjoint_residuals.append(abs(lhs - rhs))
        assert all(math.isfinite(item) for item in value(q))

    assert max(fd_errors) < 5.0e-7
    assert max(adjoint_residuals) < 2.0e-10
    print("fd_errors:", " ".join(f"{error:.6e}" for error in fd_errors))
    print("adjoint_residual:", f"{max(adjoint_residuals):.6e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
