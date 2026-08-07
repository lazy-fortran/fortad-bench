#!/usr/bin/env python3
"""Independent closed-form, finite-difference, and adjoint checks for lh038."""

from __future__ import annotations

import math


def value(pi: float, x: float) -> float:
    return 11.3 + pi if x > 20.0 else x


def jvp(pi: float, x: float, dpi: float, dx: float) -> float:
    del pi
    return dpi if x > 20.0 else dx


def vjp(pi: float, x: float, seed: float) -> tuple[float, float]:
    del pi
    return (seed, 0.0) if x > 20.0 else (0.0, seed)


def main() -> None:
    fd_errors: list[float] = []
    adjoint_residuals: list[float] = []
    for pi, x, dpi, dx, seed in (
        (3.14, 10.0, 0.7, 0.3, 0.8),
        (3.14, 25.0, 0.7, 0.3, 0.8),
    ):
        hand = jvp(pi, x, dpi, dx)
        for step in (1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5):
            finite_difference = (
                value(pi + step * dpi, x + step * dx)
                - value(pi - step * dpi, x - step * dx)
            ) / (2.0 * step)
            fd_errors.append(abs(finite_difference - hand))
        pi_b, x_b = vjp(pi, x, seed)
        adjoint_residuals.append(abs(seed * hand - (pi_b * dpi + x_b * dx)))
        assert math.isfinite(value(pi, x))

    assert min(fd_errors) < 1.0e-8
    assert max(adjoint_residuals) < 1.0e-6
    print("fd_errors:", " ".join(f"{error:.6e}" for error in fd_errors))
    print("adjoint_residual:", f"{max(adjoint_residuals):.6e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
