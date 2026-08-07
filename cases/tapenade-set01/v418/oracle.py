#!/usr/bin/env python3
"""Independent semantic oracle for v418's intended MPI ring transfer.

The oracle does not parse or execute Fortran, MPI, Tapenade, or FortAD.  It
models only the visible payload contract: rank r sends 1000+r to r+1 and
receives the predecessor's payload.  The derivative of that permutation is
checked by central differences and an adjoint dot-product identity.
"""

from __future__ import annotations

import math


def ring(values: list[float]) -> list[float]:
    world_size = len(values)
    assert world_size >= 2
    return [values[(rank - 1) % world_size] for rank in range(world_size)]


def jvp(direction: list[float]) -> list[float]:
    return ring(direction)


def vjp(cotangent: list[float]) -> list[float]:
    world_size = len(cotangent)
    return [cotangent[(rank + 1) % world_size] for rank in range(world_size)]


def main() -> None:
    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for world_size in range(2, 9):
        values = [1000.0 + rank for rank in range(world_size)]
        direction = [0.125 - 0.031 * rank for rank in range(world_size)]
        cotangent = [0.4 + 0.17 * rank for rank in range(world_size)]
        epsilon = 1.0e-6
        plus = ring([value + epsilon * delta for value, delta in zip(values, direction)])
        minus = ring([value - epsilon * delta for value, delta in zip(values, direction)])
        finite_difference = [
            (high - low) / (2.0 * epsilon) for high, low in zip(plus, minus)
        ]
        max_fd_error = max(
            max_fd_error,
            max(abs(estimate - exact) for estimate, exact in zip(finite_difference, jvp(direction))),
        )
        left = sum(weight * value for weight, value in zip(cotangent, jvp(direction)))
        right = sum(value * delta for value, delta in zip(vjp(cotangent), direction))
        max_adjoint_error = max(max_adjoint_error, abs(left - right))
        assert ring(values) == [1000.0 + (rank - 1) % world_size for rank in range(world_size)]

    assert math.isfinite(max_fd_error)
    assert math.isfinite(max_adjoint_error)
    assert max_fd_error < 1.0e-7, max_fd_error
    assert max_adjoint_error < 1.0e-12, max_adjoint_error
    print(
        "oracle_status: pass "
        f"world_sizes=2..8 finite_difference_max_error: {max_fd_error:.3e} "
        f"adjoint_identity_residual: {max_adjoint_error:.3e}"
    )


if __name__ == "__main__":
    main()
