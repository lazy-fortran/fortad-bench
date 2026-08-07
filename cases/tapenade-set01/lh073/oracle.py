#!/usr/bin/env python3
"""Independent state-map, JVP, finite-difference, and VJP checks for lh073."""

from __future__ import annotations

import math
from typing import Sequence


N = 10
QSIZE = 2 * N
OSIZE = 2 * N + 1


def value(q: Sequence[float]) -> tuple[float, ...]:
    a = list(q[:N])
    b = list(q[N:])
    a_out = [b[i] * a[i] for i in range(N)]
    b_out = [item * item for item in b]
    b_out[-1] = b_out[-1] * b_out[-1]
    objective = sum(a_out) + sum(b_out)
    return tuple(a_out + b_out + [objective])


def hand_jvp(q: Sequence[float], dq: Sequence[float]) -> tuple[float, ...]:
    a = list(q[:N])
    b = list(q[N:])
    da = list(dq[:N])
    db = list(dq[N:])
    a_out = [b[i] * a[i] for i in range(N)]
    da_out = [db[i] * a[i] + b[i] * da[i] for i in range(N)]
    b_out = [item * item for item in b]
    db_out = [2.0 * b[i] * db[i] for i in range(N)]
    db_out[-1] = 4.0 * b[-1] ** 3 * db[-1]
    b_out[-1] = b[-1] ** 4
    return tuple(da_out + db_out + [sum(da_out) + sum(db_out)])


def jacobian(q: Sequence[float]) -> list[tuple[float, ...]]:
    columns: list[tuple[float, ...]] = []
    for i in range(QSIZE):
        direction = [0.0] * QSIZE
        direction[i] = 1.0
        columns.append(hand_jvp(q, direction))
    return [tuple(column[row] for column in columns) for row in range(OSIZE)]


def main() -> int:
    q = tuple(
        [0.17 * (i + 1) - 0.4 for i in range(N)]
        + [0.08 * (i + 1) + 0.35 for i in range(N)]
    )
    direction = tuple(((-1.0) ** i) * (0.013 * (i + 1) + 0.002) for i in range(QSIZE))
    output_seed = tuple(0.019 * (i + 2) for i in range(OSIZE))
    tangent = hand_jvp(q, direction)

    fd_errors: list[float] = []
    for step in (1.0e-3, 1.0e-4, 1.0e-5):
        plus = tuple(a + step * b for a, b in zip(q, direction))
        minus = tuple(a - step * b for a, b in zip(q, direction))
        finite_difference = tuple(
            (a - b) / (2.0 * step) for a, b in zip(value(plus), value(minus))
        )
        fd_errors.extend(abs(a - b) for a, b in zip(finite_difference, tangent))

    matrix = jacobian(q)
    vjp = tuple(
        sum(matrix[row][col] * output_seed[row] for row in range(OSIZE))
        for col in range(QSIZE)
    )
    adjoint_residual = abs(
        sum(a * b for a, b in zip(output_seed, tangent))
        - sum(a * b for a, b in zip(vjp, direction))
    )

    objective_seed = 0.73
    objective_vjp = tuple(
        sum(matrix[2 * N][col] * objective_seed for _ in [0])
        for col in range(QSIZE)
    )
    expected_objective_vjp = tuple(
        objective_seed * q[N + i]
        if i < N
        else objective_seed
        * (
            q[i - N] + (4.0 * q[i] ** 3 if i == 2 * N - 1 else 2.0 * q[i])
        )
        for i in range(QSIZE)
    )

    if (
        max(fd_errors) >= 2.0e-7
        or adjoint_residual >= 2.0e-10
        or max(abs(a - b) for a, b in zip(objective_vjp, expected_objective_vjp)) >= 2.0e-12
        or not all(math.isfinite(item) for item in value(q))
    ):
        raise SystemExit(
            f"oracle mismatch: fd={max(fd_errors)} adjoint={adjoint_residual}"
        )

    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max(fd_errors):.6e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.6e}")
    print(f"objective_reverse_a1: {objective_vjp[0]:.17e}")
    print(f"objective_reverse_b10: {objective_vjp[-1]:.17e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
