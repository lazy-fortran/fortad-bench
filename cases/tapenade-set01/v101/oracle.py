#!/usr/bin/env python3
"""Independent JVP/VJP, finite-difference, and adjoint checks for v101."""

from __future__ import annotations

import math
from typing import Sequence


def value(x: Sequence[float]) -> tuple[float]:
    return (4.0 * x[0] * x[1],)


def hand_jvp(x: Sequence[float], dx: Sequence[float]) -> tuple[float]:
    return (4.0 * (dx[0] * x[1] + x[0] * dx[1]),)


def jacobian(x: Sequence[float]) -> tuple[tuple[float, float]]:
    return ((4.0 * x[1], 4.0 * x[0]),)


def main() -> int:
    points = ((1.25, -0.75), (-2.0, 0.4), (0.2, 3.5), (4.0, 2.25))
    direction = (0.17, -0.23)
    max_fd_error = 0.0
    max_adjoint_residual = 0.0

    for x in points:
        tangent = hand_jvp(x, direction)
        for step in (1.0e-3, 1.0e-4, 1.0e-5, 1.0e-6):
            plus = tuple(a + step * b for a, b in zip(x, direction))
            minus = tuple(a - step * b for a, b in zip(x, direction))
            finite_difference = tuple(
                (a - b) / (2.0 * step)
                for a, b in zip(value(plus), value(minus))
            )
            max_fd_error = max(
                max_fd_error,
                *(abs(a - b) for a, b in zip(finite_difference, tangent)),
            )

        seed = (0.61,)
        matrix = jacobian(x)
        vjp = tuple(matrix[0][column] * seed[0] for column in range(2))
        max_adjoint_residual = max(
            max_adjoint_residual,
            abs(sum(a * b for a, b in zip(seed, tangent))
                - sum(a * b for a, b in zip(vjp, direction))),
        )
        if not all(math.isfinite(item) for item in value(x)):
            raise SystemExit("non-finite bounded value")

    if max_fd_error >= 2.0e-8 or max_adjoint_residual >= 2.0e-12:
        raise SystemExit(
            f"oracle mismatch: fd={max_fd_error} adjoint={max_adjoint_residual}"
        )

    x = points[0]
    seed = (0.61,)
    matrix = jacobian(x)
    vjp = tuple(matrix[0][column] * seed[0] for column in range(2))
    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max_fd_error:.6e}")
    print(f"adjoint_identity_residual: {max_adjoint_residual:.6e}")
    print(f"hand_y_vjp_x1: {vjp[0]:.17e}")
    print(f"hand_y_vjp_x2: {vjp[1]:.17e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
