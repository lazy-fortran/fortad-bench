"""Independent numerical oracle for set02/v128."""

from __future__ import annotations

import math


def value(x: float) -> float:
    return math.exp(-0.5 * x)


def jvp(x: float, dx: float) -> float:
    return value(x) * (-0.5 * dx)


def vjp(x: float, seed: float) -> float:
    return seed * (-0.5 * value(x))


def main() -> None:
    max_fd = 0.0
    max_adjoint = 0.0
    for x, dx, seed in ((1.2, 0.3, 1.7), (-0.4, -0.8, -0.6), (2.5, 1.1, 0.25)):
        eps = 1.0e-6
        fd = (value(x + eps * dx) - value(x - eps * dx)) / (2.0 * eps)
        tangent = jvp(x, dx)
        max_fd = max(max_fd, abs(fd - tangent))
        max_adjoint = max(max_adjoint, abs(seed * tangent - vjp(x, seed) * dx))
    assert max_fd < 1.0e-9, max_fd
    assert max_adjoint < 1.0e-14, max_adjoint
    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max_fd:.16e}")
    print(f"adjoint_identity_max_error: {max_adjoint:.16e}")


if __name__ == "__main__":
    main()
