#!/usr/bin/env python3
"""Independent JVP/VJP and finite-difference checks for set01/v02."""

from __future__ import annotations

import math
from typing import Sequence


def value(q: Sequence[float]) -> tuple[float, ...]:
    state, i3 = q
    i1 = 2.0
    if i3 < 0.0:
        i3 = i1 - state
    i1 = state - i3
    scale = 2.3
    x2 = 5.0
    x1 = i1 * scale
    if i1 > 3.0:
        x2 = x2 + i1 - 3.0 * scale
    else:
        x2 = 12.0
        x1 = 2.0 * x1 + x2
    o1 = 35.0 * scale * x1 / x2
    return (i3, o1, 35.0, 2.0)


def hand_jvp(q: Sequence[float], dq: Sequence[float]) -> tuple[float, ...]:
    state, i3 = q
    stated, i3d = dq
    i1 = 2.0
    if i3 < 0.0:
        i3d = -stated
        i3 = i1 - state
    i1 = state - i3
    i1d = stated - i3d
    scale = 2.3
    x2 = 5.0
    x2d = 0.0
    x1 = i1 * scale
    x1d = i1d * scale
    if i1 > 3.0:
        x2 = x2 + i1 - 3.0 * scale
        x2d = i1d
    else:
        x2 = 12.0
        x1 = 2.0 * x1 + x2
        x1d = 2.0 * x1d
    o1d = 35.0 * scale * (x1d * x2 - x1 * x2d) / (x2 * x2)
    return (i3d, o1d, 0.0, 0.0)


def jacobian(q: Sequence[float]) -> list[tuple[float, ...]]:
    columns = []
    for index in range(2):
        direction = [0.0, 0.0]
        direction[index] = 1.0
        columns.append(hand_jvp(q, direction))
    return [tuple(column[row] for column in columns) for row in range(4)]


def main() -> int:
    points = ((1.1, 0.8), (1.1, -0.8), (5.5, 0.4), (3.0, -1.0))
    max_fd_error = 0.0
    max_adjoint_residual = 0.0
    for q in points:
        direction = (0.037, -0.061)
        tangent = hand_jvp(q, direction)
        for step in (1.0e-3, 1.0e-4, 1.0e-5):
            plus = tuple(a + step * b for a, b in zip(q, direction))
            minus = tuple(a - step * b for a, b in zip(q, direction))
            finite_difference = tuple(
                (a - b) / (2.0 * step)
                for a, b in zip(value(plus), value(minus))
            )
            max_fd_error = max(
                max_fd_error,
                *(abs(a - b) for a, b in zip(finite_difference, tangent)),
            )

        seed = (0.23, -0.41, 0.17, 0.09)
        matrix = jacobian(q)
        vjp = tuple(
            sum(matrix[row][column] * seed[row] for row in range(4))
            for column in range(2)
        )
        max_adjoint_residual = max(
            max_adjoint_residual,
            abs(
                sum(a * b for a, b in zip(seed, tangent))
                - sum(a * b for a, b in zip(vjp, direction))
            ),
        )

        if not all(math.isfinite(item) for item in value(q)):
            raise SystemExit("non-finite bounded value")

    if max_fd_error >= 2.0e-6 or max_adjoint_residual >= 2.0e-10:
        raise SystemExit(
            f"oracle mismatch: fd={max_fd_error} adjoint={max_adjoint_residual}"
        )

    q = (1.1, 0.8)
    matrix = jacobian(q)
    seed = (0.0, 0.8, 0.0, 0.0)
    o1_vjp = tuple(
        sum(matrix[row][column] * seed[row] for row in range(4))
        for column in range(2)
    )
    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max_fd_error:.6e}")
    print(f"adjoint_identity_residual: {max_adjoint_residual:.6e}")
    print(f"hand_o1_vjp_i2: {o1_vjp[0]:.17e}")
    print(f"hand_o1_vjp_i3: {o1_vjp[1]:.17e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
