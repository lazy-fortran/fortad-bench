#!/usr/bin/env python3
"""Independent numerical oracle for the bounded lh054 scaling probe."""

from __future__ import annotations

import math


def primal(x: float) -> float:
    return 2.0 * x


def hand_jvp(direction: float) -> float:
    return 2.0 * direction


def hand_vjp(seed: float) -> float:
    return 2.0 * seed


def main() -> int:
    x = 1.25
    direction = -0.375
    seed = 0.7
    h = 1.0e-6

    hand = hand_jvp(direction)
    finite = (primal(x + h) - primal(x - h)) / (2.0 * h) * direction
    fd_error = abs(finite - hand)
    vjp = hand_vjp(seed)
    adjoint_residual = abs(hand * seed - direction * vjp)

    sweep_error = 0.0
    for point in (-4.0, -0.25, 0.0, 0.5, 3.75):
        estimate = (primal(point + h) - primal(point - h)) / (2.0 * h)
        sweep_error = max(sweep_error, abs(estimate - 2.0))

    status = (
        fd_error < 1.0e-9
        and sweep_error < 1.0e-9
        and adjoint_residual < 1.0e-15
        and math.isclose(primal(x), 2.5, rel_tol=0.0, abs_tol=1.0e-15)
    )
    print("oracle_status: pass" if status else "oracle_status: fail")
    print(f"primal_objective: {primal(x):.17e}")
    print(f"hand_jvp: {hand:.17e}")
    print(f"hand_vjp: {vjp:.17e}")
    print(f"finite_difference: {finite:.17e}")
    print(f"fd_error: {fd_error:.17e}")
    print(f"central_difference_sweep_error: {sweep_error:.17e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.17e}")
    print(f"direction: {direction:.17e}")
    print(f"seed: {seed:.17e}")
    return 0 if status else 1


if __name__ == "__main__":
    raise SystemExit(main())
