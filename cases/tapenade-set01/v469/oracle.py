"""Independent numerical oracle for v469's bounded one-element sin map."""

from __future__ import annotations

import math


def value(x: float) -> float:
    return math.sin(2.0 * math.pi * x)


def jvp(x: float, dx: float) -> float:
    return 2.0 * math.pi * math.cos(2.0 * math.pi * x) * dx


def vjp(x: float, seed: float) -> float:
    return seed * 2.0 * math.pi * math.cos(2.0 * math.pi * x)


def main() -> None:
    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for x, dx, seed in (
        (0.125, -0.3, 0.7),
        (-0.4, 0.2, -1.1),
        (1.75, 0.05, 2.5),
    ):
        epsilon = 1.0e-6
        finite_difference = (
            value(x + epsilon * dx) - value(x - epsilon * dx)
        ) / (2.0 * epsilon)
        tangent = jvp(x, dx)
        max_fd_error = max(max_fd_error, abs(finite_difference - tangent))
        max_adjoint_error = max(
            max_adjoint_error,
            abs(seed * tangent - vjp(x, seed) * dx),
        )

    if max_fd_error > 1.0e-9 or max_adjoint_error > 1.0e-12:
        raise SystemExit(
            f"oracle failure fd={max_fd_error:.3e} adjoint={max_adjoint_error:.3e}"
        )
    print("oracle_status: pass bounded_domain=one-element-finite-real")
    print(f"finite_difference_max_error: {max_fd_error:.16e}")
    print(f"adjoint_identity_residual: {max_adjoint_error:.16e}")


if __name__ == "__main__":
    main()
