#!/usr/bin/env python3
"""Independent arithmetic oracle for the intended root/toto fixed-point map.

The exact corpus call passes a REAL actual to an INTEGER dummy and the exact
root also prints.  This model deliberately checks only the closed arithmetic
described by the assignments, with the intended initial value 24.0.  It is
not a repaired source port and does not invoke Tapenade, FortAD, or a
compiler.
"""

from __future__ import annotations

import math


TOLERANCE = 1.0e-10
MAX_ITERATIONS = 10000


def root_value(x: float, initial: float = 24.0) -> tuple[float, int]:
    """Return the scalar y and iteration count for the source's outer loop."""

    z = initial
    oz = z + 1.0
    iterations = 0
    while (z - oz) ** 2 >= TOLERANCE:
        oz = z
        # The source assigns oz=z immediately before this inner test, so the
        # inner fixed-point loop is skipped on every outer iteration.
        z = 2.0 / (oz + x)
        iterations += 1
        if iterations >= MAX_ITERATIONS:
            raise RuntimeError("fixed-point iteration did not converge")
    return z * x, iterations


def root_jvp(x: float, dx: float, initial: float = 24.0) -> float:
    """Differentiate the same finite iteration sequence with respect to x."""

    z = initial
    oz = z + 1.0
    zd = 0.0
    while (z - oz) ** 2 >= TOLERANCE:
        oz = z
        old_z = z
        old_zd = zd
        z = 2.0 / (oz + x)
        zd = -2.0 * (old_zd + dx) / (old_z + x) ** 2
    return z * dx + x * zd


def root_vjp(x: float, seed: float, initial: float = 24.0) -> float:
    """Return the reverse sensitivity for scalar output y and input x."""

    eps = 1.0e-6
    derivative = (root_value(x + eps, initial)[0] - root_value(x - eps, initial)[0]) / (2.0 * eps)
    return seed * derivative


def main() -> int:
    finite_difference_max_error = 0.0
    adjoint_max_error = 0.0
    cases = ((0.8, 0.2, 0.6), (1.0, -0.3, -1.2), (1.2, 0.4, 2.5))
    for x, dx, seed in cases:
        eps = 1.0e-6
        finite_difference = (
            root_value(x + eps)[0] - root_value(x - eps)[0]
        ) / (2.0 * eps)
        finite_difference_max_error = max(
            finite_difference_max_error,
            abs(finite_difference - root_jvp(x, 1.0)),
        )
        lhs = seed * root_jvp(x, dx)
        rhs = root_vjp(x, seed) * dx
        adjoint_max_error = max(adjoint_max_error, abs(lhs - rhs))

    if finite_difference_max_error > 3.0e-7:
        raise SystemExit(f"finite-difference error too large: {finite_difference_max_error}")
    if adjoint_max_error > 3.0e-7:
        raise SystemExit(f"adjoint residual too large: {adjoint_max_error}")

    value, iterations = root_value(1.0)
    if not math.isfinite(value):
        raise SystemExit("non-finite oracle value")
    print("oracle_behavioral_cases: 3")
    print(f"oracle_sample_value_x1: {value:.16e}")
    print(f"oracle_sample_iterations_x1: {iterations}")
    print(f"oracle_finite_difference_max_error: {finite_difference_max_error:.16e}")
    print(f"oracle_adjoint_max_error: {adjoint_max_error:.16e}")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
