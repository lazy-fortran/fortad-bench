#!/usr/bin/env python3
"""Independent hand JVP, finite-difference, and adjoint checks for lh059."""

from __future__ import annotations

import math


N = 31
INITIAL_I = 6
BODY_STEPS = 5


def initial_state() -> tuple[list[float], list[float], list[float], list[float]]:
    t = [0.0] + [0.10 + 0.013 * i for i in range(1, N + 1)]
    u = [0.0] + [-0.20 + 0.007 * i for i in range(1, N + 1)]
    # This path visits 6, 11, 16, 21, 26 and reaches t(31)<=0 at the
    # original loop guard.  It exercises both the LOG branch and GOTO-5 path.
    t[6] = 2.0
    u[6] = -0.4
    for i in (11, 16, 21, 26):
        t[i] = -0.25
        u[i] = -1.0
    t[31] = -1.0
    td = [0.0] + [0.002 - 0.00011 * i for i in range(1, N + 1)]
    ud = [0.0] + [-0.003 + 0.00017 * i for i in range(1, N + 1)]
    return t, u, td, ud


def primal(t: list[float], u: list[float]) -> tuple[list[float], list[float]]:
    t = t[:]
    u = u[:]
    i = INITIAL_I
    for _ in range(BODY_STEPS):
        if t[i] > 1.0:
            u[i] += math.log(t[i])
            t[i] = 3.0 * u[i]
        else:
            u[i] += t[i - 5]
            if u[i] >= 0.0:
                t[i] = 3.0 * u[i]
        i += 5
        t[i] = 2.0 * t[i] + 1.0
    return t, u


def hand_jvp(
    t: list[float], u: list[float], td: list[float], ud: list[float]
) -> tuple[list[float], list[float], list[float], list[float]]:
    t = t[:]
    u = u[:]
    td = td[:]
    ud = ud[:]
    i = INITIAL_I
    for _ in range(BODY_STEPS):
        if t[i] > 1.0:
            ud[i] += td[i] / t[i]
            u[i] += math.log(t[i])
            td[i] = 3.0 * ud[i]
            t[i] = 3.0 * u[i]
        else:
            ud[i] += td[i - 5]
            u[i] += t[i - 5]
            if u[i] >= 0.0:
                td[i] = 3.0 * ud[i]
                t[i] = 3.0 * u[i]
        i += 5
        td[i] = 2.0 * td[i]
        t[i] = 2.0 * t[i] + 1.0
    return t, u, td, ud


def flatten(t: list[float], u: list[float]) -> list[float]:
    return t[1:] + u[1:]


def dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def main() -> int:
    t, u, td, ud = initial_state()
    hand_t, hand_u, hand_td, hand_ud = hand_jvp(t, u, td, ud)
    h = 1.0e-6
    plus_t, plus_u = primal(
        [a + h * b for a, b in zip(t, td)],
        [a + h * b for a, b in zip(u, ud)],
    )
    minus_t, minus_u = primal(
        [a - h * b for a, b in zip(t, td)],
        [a - h * b for a, b in zip(u, ud)],
    )
    finite = [
        (a - b) / (2.0 * h)
        for a, b in zip(flatten(plus_t, plus_u), flatten(minus_t, minus_u))
    ]
    analytical = flatten(hand_td, hand_ud)
    fd_error = max(abs(a - b) for a, b in zip(analytical, finite))
    if not math.isfinite(fd_error) or fd_error > 3.0e-8:
        raise SystemExit(f"finite-difference mismatch: {fd_error}")

    # Build J from the same hand-derived elementary JVP, then check the
    # bilinear adjoint identity w^T(Jv)=(J^Tw)^T v.  No generated code is
    # involved in this oracle.
    seed = [0.11 - 0.003 * i for i in range(2 * N)]
    columns: list[list[float]] = []
    for component in range(2 * N):
        basis_t = [0.0] * (N + 1)
        basis_u = [0.0] * (N + 1)
        if component < N:
            basis_t[component + 1] = 1.0
        else:
            basis_u[component - N + 1] = 1.0
        _, _, basis_td, basis_ud = hand_jvp(t, u, basis_t, basis_u)
        columns.append(flatten(basis_td, basis_ud))
    jv = analytical
    # Form the transpose action directly to avoid relying on a matrix package
    # in the reproducible runner.
    jt_seed = [
        sum(columns[column][row] * seed[row] for row in range(2 * N))
        for column in range(2 * N)
    ]
    adjoint_residual = abs(dot(seed, jv) - dot(flatten(td, ud), jt_seed))
    if not math.isfinite(adjoint_residual) or adjoint_residual > 2.0e-12:
        raise SystemExit(f"adjoint identity mismatch: {adjoint_residual}")

    print("oracle_status: pass")
    print(f"finite_difference_max_error: {fd_error:.16e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.16e}")
    print(f"primal_t6: {hand_t[6]:.16e}")
    print(f"primal_u11: {hand_u[11]:.16e}")
    print(f"jvp_t6: {hand_td[6]:.16e}")
    print(f"jvp_u11: {hand_ud[11]:.16e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
