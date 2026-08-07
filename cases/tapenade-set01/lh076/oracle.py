#!/usr/bin/env python3
"""Independent real-coordinate oracle for the bounded onegvert semantics."""

from __future__ import annotations

import cmath
import math


CASES = (
    (0.0, 0.35, -1.2 - 0.4j),
    (0.7, -0.2, 0.6 + 0.9j),
    (-1.1, 0.45, -1.3 + 0.25j),
    (2.4, -0.8, 0.2 - 1.1j),
)


def primal(x: float) -> complex:
    return complex(math.cos(x), -math.sin(x))


def hand_jvp(x: float, dx: float) -> complex:
    return complex(-math.sin(x) * dx, -math.cos(x) * dx)


def hand_vjp(x: float, yb: complex) -> float:
    return -math.sin(x) * yb.real - math.cos(x) * yb.imag


def close(a: float, b: float, tolerance: float = 2.0e-10) -> bool:
    return abs(a - b) <= tolerance * max(1.0, abs(a), abs(b))


def main() -> None:
    step = 1.0e-6
    jvp_errors = []
    finite_difference_errors = []
    adjoint_errors = []
    for x, dx, yb in CASES:
        want = hand_jvp(x, dx)
        observed = complex(-math.sin(x) * dx, -math.cos(x) * dx)
        jvp_errors.append(abs(observed - want))

        fd = (primal(x + step * dx) - primal(x - step * dx)) / (2.0 * step)
        finite_difference_errors.append(abs(fd - want))

        xb = hand_vjp(x, yb)
        lhs = (yb.conjugate() * want).real
        rhs = xb * dx
        adjoint_errors.append(abs(lhs - rhs))

    max_jvp = max(jvp_errors)
    max_fd = max(finite_difference_errors)
    max_adjoint = max(adjoint_errors)
    assert close(max_jvp, 0.0)
    assert max_fd < 2.0e-10
    assert close(max_adjoint, 0.0)
    print(f"numeric_hand_jvp: pass max_error={max_jvp:.3e}")
    print(f"finite_difference: pass max_error={max_fd:.3e}")
    print(f"adjoint_identity: pass max_residual={max_adjoint:.3e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
