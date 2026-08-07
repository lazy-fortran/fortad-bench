#!/usr/bin/env python3
"""Independent semantic oracle for the live allocated-array map in v426."""

from __future__ import annotations

import math


def setup(dim: int) -> dict[str, list[float] | None]:
    if dim <= 0:
        raise ValueError("the source allocates only positive extents")
    return {
        "tDataIn_v": [0.0] * dim,
        "tDataOut_v": [0.0] * dim,
        "inputs": [0.0] * dim,
        "outputs": [0.0] * dim,
    }


def cleanallocs(state: dict[str, list[float] | None]) -> None:
    for name in state:
        state[name] = None


def primal(base: list[float], perturbation: list[float]) -> list[float]:
    if len(base) != len(perturbation) or not base:
        raise ValueError("allocated conformable arrays are required")
    return [2.0 * (value + delta) for value, delta in zip(base, perturbation)]


def jvp(dbase: list[float], dperturbation: list[float]) -> list[float]:
    return [2.0 * (value + delta) for value, delta in zip(dbase, dperturbation)]


def vjp(cotangent: list[float]) -> tuple[list[float], list[float]]:
    gradient = [2.0 * value for value in cotangent]
    return gradient, gradient.copy()


def main() -> None:
    state = setup(3)
    assert all(len(value) == 3 for value in state.values() if value is not None)

    base = [3.0, 2.5, 4.0]
    perturbation = [0.2, -0.3, 0.4]
    dbase = [0.1, -0.2, 0.05]
    dperturbation = [-0.07, 0.04, 0.11]
    cotangent = [0.6, -0.8, 0.9]
    epsilon = 1.0e-6

    plus = primal(
        [x + epsilon * dx for x, dx in zip(base, dbase)],
        [x + epsilon * dx for x, dx in zip(perturbation, dperturbation)],
    )
    minus = primal(
        [x - epsilon * dx for x, dx in zip(base, dbase)],
        [x - epsilon * dx for x, dx in zip(perturbation, dperturbation)],
    )
    finite_difference = [
        (high - low) / (2.0 * epsilon) for high, low in zip(plus, minus)
    ]
    tangent = jvp(dbase, dperturbation)
    finite_difference_error = max(
        abs(estimate - exact) for estimate, exact in zip(finite_difference, tangent)
    )

    gradient_base, gradient_perturbation = vjp(cotangent)
    adjoint_left = sum(weight * value for weight, value in zip(cotangent, tangent))
    adjoint_right = sum(
        value * direction
        for value, direction in zip(gradient_base, dbase)
    ) + sum(
        value * direction
        for value, direction in zip(gradient_perturbation, dperturbation)
    )
    adjoint_residual = abs(adjoint_left - adjoint_right)

    cleanallocs(state)
    assert all(value is None for value in state.values())
    assert math.isfinite(finite_difference_error)
    assert math.isfinite(adjoint_residual)
    assert finite_difference_error < 1.0e-9, finite_difference_error
    assert adjoint_residual < 1.0e-12, adjoint_residual
    print(
        "oracle_status: pass "
        f"finite_difference_max_error: {finite_difference_error:.3e} "
        f"adjoint_identity_residual: {adjoint_residual:.3e}"
    )


if __name__ == "__main__":
    main()
