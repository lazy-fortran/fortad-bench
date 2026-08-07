#!/usr/bin/env python3
"""Independent hand JVP/VJP and finite-difference oracle for lh064."""

from __future__ import annotations

import math


def primal(x: float) -> float:
    if 8.0 * x > 0.0:
        return 0.0
    return 5.0 + (16.0 * x) ** 2


def derivative(x: float) -> float:
    if 8.0 * x > 0.0:
        return 0.0
    return 512.0 * x


def main() -> int:
    x = -0.5
    direction = 0.3
    seed = -0.7
    epsilon = 1.0e-6

    hand_jvp = derivative(x) * direction
    finite_difference = (
        primal(x + epsilon * direction) - primal(x - epsilon * direction)
    ) / (2.0 * epsilon)
    finite_difference_error = abs(hand_jvp - finite_difference)

    hand_vjp = seed * derivative(x)
    adjoint_residual = abs(seed * hand_jvp - hand_vjp * direction)

    sweep_error = 0.0
    for point in (-2.0, -0.25, -0.05, 0.25, 2.0):
        estimate = (primal(point + epsilon) - primal(point - epsilon)) / (2.0 * epsilon)
        sweep_error = max(sweep_error, abs(estimate - derivative(point)))

    status = (
        finite_difference_error < 1.0e-7
        and sweep_error < 1.0e-7
        and adjoint_residual < 1.0e-12
        and math.isclose(primal(x), 69.0, rel_tol=0.0, abs_tol=1.0e-12)
    )
    print("oracle_status: pass" if status else "oracle_status: fail")
    print(f"primal: {primal(x):.17e}")
    print(f"hand_jvp: {hand_jvp:.17e}")
    print(f"hand_vjp: {hand_vjp:.17e}")
    print(f"finite_difference: {finite_difference:.17e}")
    print(f"finite_difference_error: {finite_difference_error:.17e}")
    print(f"central_difference_sweep_error: {sweep_error:.17e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.17e}")
    return 0 if status else 1


if __name__ == "__main__":
    raise SystemExit(main())
