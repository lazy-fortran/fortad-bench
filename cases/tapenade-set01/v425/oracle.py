#!/usr/bin/env python3
"""Independent oracle for v425's defined output projection.

The complete upstream routine is not given a runtime support claim because
it reads local ``fichier`` before initialization.  This oracle checks only
the defined assignment to c%w%x(1), independently of Fortran, Tapenade, and
FortAD.
"""

from __future__ import annotations


def value(a1: float, b2: float) -> float:
    return a1 + b2


def jvp(da1: float, db2: float) -> float:
    return da1 + db2


def vjp(seed: float) -> tuple[float, float]:
    return seed, seed


def main() -> None:
    points = [(-3.25, 0.5), (-0.25, 4.0), (1.75, -2.5), (8.0, 9.5)]
    directions = [(0.75, -1.25), (-2.0, 0.125), (3.5, 4.25), (-1.0, 2.0)]
    epsilon = 1.0e-6
    finite_difference_error = 0.0
    adjoint_error = 0.0
    for (a1, b2), (da1, db2) in zip(points, directions):
        numerical = (
            value(a1 + epsilon * da1, b2 + epsilon * db2)
            - value(a1 - epsilon * da1, b2 - epsilon * db2)
        ) / (2.0 * epsilon)
        finite_difference_error = max(
            finite_difference_error, abs(numerical - jvp(da1, db2))
        )
        seed = 1.75
        lhs = seed * jvp(da1, db2)
        grad_a1, grad_b2 = vjp(seed)
        rhs = grad_a1 * da1 + grad_b2 * db2
        adjoint_error = max(adjoint_error, abs(lhs - rhs))

    assert finite_difference_error < 1.0e-8
    assert adjoint_error == 0.0
    print("projection: c%w%x(1) = a%w%x(1) + b%w%x(2)")
    print("excluded_path: LEN(TRIM(fichier)) reads an uninitialized local")
    print(f"finite_difference_max_error: {finite_difference_error:.3e}")
    print(f"adjoint_identity_residual: {adjoint_error:.3e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
