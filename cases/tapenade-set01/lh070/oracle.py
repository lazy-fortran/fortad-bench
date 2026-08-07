#!/usr/bin/env python3
"""Independent hand JVP/VJP, finite-difference, and adjoint checks for lh070."""

from __future__ import annotations

import math
from typing import Sequence


N = 10
QSIZE = 2 * N + 2


def value(q: Sequence[float]) -> tuple[float, ...]:
    a = list(q[:N])
    b = list(q[N : 2 * N])
    x, z = q[-2:]
    a[0] = 2.0 * a[1] + x
    y = x * z
    x = 3.0
    b[0] = 2.0 * b[1] + y
    return tuple(a + b + [x, y, z])


def hand_jvp(q: Sequence[float], dq: Sequence[float]) -> tuple[float, ...]:
    a = list(q[:N])
    b = list(q[N : 2 * N])
    da = list(dq[:N])
    db = list(dq[N : 2 * N])
    x, z = q[-2:]
    dx, dz = dq[-2:]

    da[0] = 2.0 * da[1] + dx
    a[0] = 2.0 * a[1] + x
    dy = dx * z + x * dz
    y = x * z
    dx = 0.0
    x = 3.0
    db[0] = 2.0 * db[1] + dy
    b[0] = 2.0 * b[1] + y
    return tuple(da + db + [dx, dy, dz])


def jacobian(q: Sequence[float]) -> list[tuple[float, ...]]:
    columns: list[tuple[float, ...]] = []
    for i in range(QSIZE):
        direction = [0.0] * QSIZE
        direction[i] = 1.0
        columns.append(hand_jvp(q, direction))
    return [tuple(column[row] for column in columns) for row in range(len(columns[0]))]


def main() -> int:
    q = tuple([0.1 * (i + 1) for i in range(2 * N)] + [1.2, 0.7])
    direction = tuple(((-1.0) ** i) * 0.03 * (i + 1) for i in range(QSIZE))
    seed = tuple(0.02 * (i + 2) for i in range(2 * N + 3))
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
        sum(matrix[row][col] * seed[row] for row in range(len(matrix)))
        for col in range(QSIZE)
    )
    adjoint_residual = abs(
        sum(a * b for a, b in zip(seed, tangent))
        - sum(a * b for a, b in zip(vjp, direction))
    )

    # The bounded reverse probe differentiates final y only.  x and z below
    # are the pre-call values, because y=x*z is evaluated before x=3.
    y_seed = 0.8
    expected_x_b = y_seed * q[-1]
    expected_z_b = y_seed * q[-2]
    y_seed_vector = [0.0] * len(seed)
    y_seed_vector[2 * N + 1] = y_seed
    y_vjp = tuple(
        sum(matrix[row][col] * y_seed_vector[row] for row in range(len(matrix)))
        for col in range(QSIZE)
    )
    if (
        max(fd_errors) >= 2.0e-7
        or adjoint_residual >= 2.0e-10
        or max(abs(item) for item in y_vjp[: 2 * N]) >= 2.0e-12
        or abs(y_vjp[-2] - expected_x_b) >= 2.0e-12
        or abs(y_vjp[-1] - expected_z_b) >= 2.0e-12
        or abs(expected_x_b - 0.56) >= 2.0e-12
        or abs(expected_z_b - 0.96) >= 2.0e-12
        or not all(math.isfinite(item) for item in value(q))
    ):
        raise SystemExit(
            f"oracle mismatch: fd={max(fd_errors)} adjoint={adjoint_residual}"
        )

    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max(fd_errors):.6e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.6e}")
    print(f"hand_y_vjp_x: {expected_x_b:.17e}")
    print(f"hand_y_vjp_z: {expected_z_b:.17e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
