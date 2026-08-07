#!/usr/bin/env python3
"""Independent oracle for v414's defined x-component map."""

from __future__ import annotations

import math


def value(a: float, b: float) -> float:
    return a + b


def jvp(da: float, db: float) -> float:
    return da + db


def main() -> None:
    points = [(-3.25, 0.5), (-0.25, 4.0), (1.75, -2.5), (8.0, 9.5)]
    directions = [(0.75, -1.25), (-2.0, 0.125), (3.5, 4.25), (-1.0, 2.0)]
    epsilon = 1.0e-6
    finite_difference_error = 0.0
    adjoint_error = 0.0
    for (a, b), (da, db) in zip(points, directions):
        numerical = (
            value(a + epsilon * da, b + epsilon * db)
            - value(a - epsilon * da, b - epsilon * db)
        ) / (2.0 * epsilon)
        finite_difference_error = max(
            finite_difference_error, abs(numerical - jvp(da, db))
        )
        seed = 1.75
        lhs = seed * jvp(da, db)
        rhs = seed * da + seed * db
        adjoint_error = max(adjoint_error, abs(lhs - rhs))

    assert finite_difference_error < 1.0e-8
    assert adjoint_error == 0.0
    print("observable: addvector%x = a%x + b%x")
    print("unassigned_component: addvector%y")
    print(f"finite_difference_max_error: {finite_difference_error:.3e}")
    print(f"adjoint_identity_residual: {adjoint_error:.3e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
