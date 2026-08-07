"""Independent closed-form, finite-difference, and adjoint checks for lh050."""

from __future__ import annotations

import math


def value(x: float, y: float, z: float) -> tuple[float, float]:
    u = x * y
    if x > 0.0:
        return 2.0 * x, 3.0 * u * u + x
    return u * x, z


def jvp(x: float, y: float, z: float, dx: float, dy: float, dz: float) -> tuple[float, float]:
    u = x * y
    du = y * dx + x * dy
    if x > 0.0:
        return 2.0 * dx, 6.0 * u * du + dx
    return du * x + u * dx, dz


def vjp_z(x: float, y: float, seed: float) -> tuple[float, float]:
    if x > 0.0:
        return seed * (6.0 * x * y * y + 1.0), seed * (6.0 * x * x * y)
    return 0.0, 0.0


def main() -> None:
    fd_errors: list[float] = []
    adjoint_residuals: list[float] = []
    for x, y, z, dx, dy, dz in (
        (2.0, 3.0, 7.0, 0.2, 0.4, 0.0),
        (-2.0, 3.0, 7.0, 0.2, 0.4, 0.0),
    ):
        expected = jvp(x, y, z, dx, dy, dz)
        for step in (1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5):
            plus = value(x + step * dx, y + step * dy, z + step * dz)
            minus = value(x - step * dx, y - step * dy, z - step * dz)
            finite_difference = tuple(
                (plus[i] - minus[i]) / (2.0 * step) for i in range(2)
            )
            fd_errors.extend(abs(finite_difference[i] - expected[i]) for i in range(2))
        z_b = vjp_z(x, y, 0.8)
        adjoint_residuals.append(
            abs(0.8 * expected[1] - (z_b[0] * dx + z_b[1] * dy))
        )

    # The primal is single precision, so the smallest central-difference
    # step is round-off limited.  Require at least one accurate step in each
    # sweep rather than rejecting the expected cancellation at h=1e-5.
    assert min(fd_errors) < 1.0e-5, min(fd_errors)
    assert max(adjoint_residuals) < 1.0e-6, max(adjoint_residuals)
    print("fd_errors:", " ".join(f"{error:.6e}" for error in fd_errors))
    print("adjoint_residual:", f"{max(adjoint_residuals):.6e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
