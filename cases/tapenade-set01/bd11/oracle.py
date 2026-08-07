#!/usr/bin/env python3
"""Independent finite-difference and adjoint checks for the bd11 port."""

from __future__ import annotations

import math
from typing import Sequence


N = 10
I1_SIZE = N * N
QSIZE = I1_SIZE + N + N


def value(q: Sequence[float]) -> tuple[float, ...]:
    i1 = list(q[:I1_SIZE])
    i2 = list(q[I1_SIZE : I1_SIZE + N])
    i3 = list(q[I1_SIZE + N :])
    for i in range(1, N + 1):
        for j in range(N):
            i2[j] = math.sqrt(i * abs(i * i3[j]))
            i1[j + N * (i - 1)] = i2[j] * i3[j]
    objective = i1[0]
    return tuple(i1 + i2 + i3 + [objective])


def hand_jvp(q: Sequence[float], dq: Sequence[float]) -> tuple[float, ...]:
    i1 = list(q[:I1_SIZE])
    i2 = list(q[I1_SIZE : I1_SIZE + N])
    i3 = list(q[I1_SIZE + N :])
    di1 = list(dq[:I1_SIZE])
    di2 = list(dq[I1_SIZE : I1_SIZE + N])
    di3 = list(dq[I1_SIZE + N :])
    for i in range(1, N + 1):
        for j in range(N):
            x = i3[j]
            dx = di3[j]
            root = math.sqrt(i * abs(i * x))
            # The test point is positive, so this is the smooth derivative
            # of sqrt(i*abs(i*x)) on the selected trace.
            droot = (i * i) * dx / (2.0 * root)
            i2[j] = root
            di2[j] = droot
            i1[j + N * (i - 1)] = root * x
            di1[j + N * (i - 1)] = droot * x + root * dx
    objective = i1[0]
    dobjective = di1[0]
    return tuple(di1 + di2 + di3 + [dobjective])


def jacobian(q: Sequence[float]) -> list[tuple[float, ...]]:
    columns: list[tuple[float, ...]] = []
    for index in range(QSIZE):
        direction = [0.0] * QSIZE
        direction[index] = 1.0
        columns.append(hand_jvp(q, direction))
    return [tuple(column[row] for column in columns) for row in range(QSIZE + 1)]


def main() -> int:
    q = tuple(
        [0.07 * (index + 1) for index in range(I1_SIZE)]
        + [-0.11 * (index + 1) for index in range(N)]
        + [0.35 + 0.08 * index for index in range(N)]
    )
    direction = tuple(
        0.013 * ((-1.0) ** index) * (index + 1) for index in range(QSIZE)
    )
    seed = tuple(0.004 * (index + 2) for index in range(QSIZE + 1))
    tangent = hand_jvp(q, direction)

    fd_errors: list[float] = []
    for step in (1.0e-3, 1.0e-4, 1.0e-5):
        plus = tuple(a + step * b for a, b in zip(q, direction))
        minus = tuple(a - step * b for a, b in zip(q, direction))
        finite_difference = tuple(
            (a - b) / (2.0 * step)
            for a, b in zip(value(plus), value(minus))
        )
        fd_errors.extend(abs(a - b) for a, b in zip(finite_difference, tangent))

    matrix = jacobian(q)
    vjp = tuple(
        sum(matrix[row][column] * seed[row] for row in range(QSIZE + 1))
        for column in range(QSIZE)
    )
    adjoint_residual = abs(
        sum(a * b for a, b in zip(seed, tangent))
        - sum(a * b for a, b in zip(vjp, direction))
    )
    objective_gradient = tuple(matrix[QSIZE][column] for column in range(QSIZE))

    if (
        max(fd_errors) >= 5.0e-5
        or adjoint_residual >= 2.0e-10
        or any(abs(item) >= 2.0e-12 for item in objective_gradient[:I1_SIZE])
        or any(abs(item) >= 2.0e-12 for item in objective_gradient[I1_SIZE : I1_SIZE + N])
        or not all(math.isfinite(item) for item in value(q))
    ):
        raise SystemExit(
            f"oracle mismatch: fd={max(fd_errors)} adjoint={adjoint_residual}"
        )

    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max(fd_errors):.6e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.6e}")
    print(f"objective_value: {value(q)[-1]:.9e}")
    print(
        f"objective_i3_gradient_first: {objective_gradient[I1_SIZE + N]:.9e}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
