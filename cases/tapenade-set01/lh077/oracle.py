#!/usr/bin/env python3
"""Independent value/JVP/VJP, finite-difference, and adjoint checks for lh077."""

from __future__ import annotations

import math
from typing import Sequence


N = 100


def value(q: Sequence[float]) -> float:
    a = q[:N]
    b, c = q[N:]
    # The source uses integer operands in 1/i, so only i=1 contributes.
    l1sq = 1.0
    return 8.5 * ((c + l1sq) * b + sum(x * x for x in a))


def hand_jvp(q: Sequence[float], dq: Sequence[float]) -> float:
    a = q[:N]
    b, c = q[N:]
    da = dq[:N]
    db, dc = dq[N:]
    return 8.5 * (
        dc * b + (c + 1.0) * db + sum(2.0 * x * dx for x, dx in zip(a, da))
    )


def hand_vjp(q: Sequence[float], seed: float) -> tuple[float, ...]:
    a = q[:N]
    b, c = q[N:]
    return tuple([seed * 17.0 * x for x in a] + [seed * 8.5 * (c + 1.0), seed * 8.5 * b])


def main() -> int:
    q = tuple([0.01 * (i + 1) for i in range(N)] + [1.7, -0.4])
    dq = tuple([(-1.0) ** i * 0.003 * (i + 1) for i in range(N)] + [0.17, -0.23])
    seed = 0.61
    tangent = hand_jvp(q, dq)

    fd_errors = []
    for step in (1.0e-3, 1.0e-4, 1.0e-5):
        plus = tuple(x + step * dx for x, dx in zip(q, dq))
        minus = tuple(x - step * dx for x, dx in zip(q, dq))
        finite_difference = (value(plus) - value(minus)) / (2.0 * step)
        fd_errors.append(abs(finite_difference - tangent))

    vjp = hand_vjp(q, seed)
    adjoint_residual = abs(seed * tangent - sum(x * dx for x, dx in zip(vjp, dq)))
    expected = (seed * 17.0 * q[0], seed * 8.5 * (q[N + 1] + 1.0), seed * 8.5 * q[N])
    if (
        max(fd_errors) >= 2.0e-7
        or adjoint_residual >= 2.0e-10
        or abs(vjp[0] - expected[0]) >= 2.0e-12
        or abs(vjp[N] - expected[1]) >= 2.0e-12
        or abs(vjp[N + 1] - expected[2]) >= 2.0e-12
        or not math.isfinite(value(q))
    ):
        raise SystemExit(
            f"oracle mismatch: fd={max(fd_errors)} adjoint={adjoint_residual}"
        )

    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max(fd_errors):.6e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.6e}")
    print(f"hand_vjp_a1: {vjp[0]:.17e}")
    print(f"hand_vjp_b: {vjp[N]:.17e}")
    print(f"hand_vjp_c: {vjp[N + 1]:.17e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
