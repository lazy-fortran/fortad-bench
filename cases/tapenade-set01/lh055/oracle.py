#!/usr/bin/env python3
"""Independent JVP/VJP, finite-difference, and adjoint checks for lh055."""

from __future__ import annotations

import math


def primal(b: float) -> float:
    return b * b + 0.25 * b


def derivative(b: float) -> float:
    return 2.0 * b + 0.25


def main() -> int:
    b = 1.7
    bd = -0.35
    seed = 0.8
    eps = 1.0e-6

    value = primal(b)
    jvp = derivative(b) * bd
    plus = primal(b + eps * bd)
    minus = primal(b - eps * bd)
    finite_difference = (plus - minus) / (2.0 * eps)
    fd_error = abs(jvp - finite_difference)

    # The scalar VJP is seed*(dy/db); this is checked against the same
    # directional pairing used by the adjoint identity.
    vjp = seed * derivative(b)
    adjoint_residual = abs(seed * jvp - vjp * bd)

    if fd_error >= 2.0e-8 or adjoint_residual >= 2.0e-14:
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
    print(f"b={b:.17e} bd={bd:.17e} seed={seed:.17e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
