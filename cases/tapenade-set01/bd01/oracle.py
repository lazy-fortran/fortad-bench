#!/usr/bin/env python3
"""Independent scalar JVP/VJP and finite-difference checks for the port."""

from __future__ import annotations


def value(b: float, c: float) -> float:
    return b * c


def jvp(b: float, c: float, db: float, dc: float) -> float:
    return db * c + b * dc


def vjp(b: float, c: float, seed: float) -> tuple[float, float]:
    return seed * c, seed * b


def main() -> None:
    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for b, c, db, dc, seed in (
        (1.25, -0.75, 0.2, -0.4, 0.6),
        (-0.4, 2.1, -0.7, 0.3, -1.2),
        (3.0, 0.125, 0.01, 0.09, 2.5),
    ):
        eps = 1.0e-6
        fd_b = (value(b + eps, c) - value(b - eps, c)) / (2.0 * eps)
        fd_c = (value(b, c + eps) - value(b, c - eps)) / (2.0 * eps)
        want_b, want_c = vjp(b, c, 1.0)
        max_fd_error = max(max_fd_error, abs(fd_b - want_b), abs(fd_c - want_c))

        lhs = seed * jvp(b, c, db, dc)
        rhs = sum(g * d for g, d in zip(vjp(b, c, seed), (db, dc)))
        max_adjoint_error = max(max_adjoint_error, abs(lhs - rhs))

    if max_fd_error > 3.0e-6 or max_adjoint_error > 1.0e-12:
        raise SystemExit("oracle failure")
    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max_fd_error:.16e}")
    print(f"adjoint_identity_residual: {max_adjoint_error:.16e}")
    print(f"sample_value: {value(1.25, -0.75):.16e}")


if __name__ == "__main__":
    main()
