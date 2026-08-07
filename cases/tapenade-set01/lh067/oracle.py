#!/usr/bin/env python3
"""Independent normal-read-path JVP, finite-difference, and adjoint checks."""

from __future__ import annotations

import math


def primal(z: float) -> float:
    # This is the successful branch of read7, including Fortran's truncating
    # real-to-integer assignment.  The probe remains in 1 < z < 2.
    ncmax = int(z + 10)
    return ncmax * z


def hand_derivative(z: float) -> float:
    if not 1.0 < z < 2.0:
        raise ValueError("the bounded derivative witness requires 1 < z < 2")
    return 11.0


def main() -> int:
    z = 1.7
    zd = -0.35
    seed = 0.8
    eps = 1.0e-6

    value = primal(z)
    jvp = hand_derivative(z) * zd
    plus = primal(z + eps * zd)
    minus = primal(z - eps * zd)
    finite_difference = (plus - minus) / (2.0 * eps)
    fd_error = abs(jvp - finite_difference)

    # The scalar VJP is seed*(dy/dz); compare the two sides of the adjoint
    # identity without using generated FortAD code.
    vjp = seed * hand_derivative(z)
    adjoint_residual = abs(seed * jvp - vjp * zd)

    if fd_error >= 2.0e-6 or adjoint_residual >= 2.0e-14:
        raise SystemExit(
            f"oracle mismatch: fd_error={fd_error} adjoint={adjoint_residual}"
        )

    print("oracle_status: pass")
    print(f"primal: {value:.17e}")
    print(f"hand_jvp: {jvp:.17e}")
    print(f"hand_vjp: {vjp:.17e}")
    print(f"finite_difference: {finite_difference:.17e}")
    print(f"fd_error: {fd_error:.17e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.17e}")
    print(f"z={z:.17e} zd={zd:.17e} seed={seed:.17e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
