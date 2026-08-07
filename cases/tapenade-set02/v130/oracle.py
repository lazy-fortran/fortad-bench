"""Independent numerical oracle for set02/v130."""

from __future__ import annotations


def value(x: float) -> float:
    return x * x


def jvp(x: float, dx: float) -> float:
    return 2.0 * x * dx


def vjp(x: float, seed: float) -> float:
    return seed * 2.0 * x


def main() -> None:
    max_fd = 0.0
    max_adjoint = 0.0
    for x, dx, seed in ((1.25, -0.4, 1.3), (-2.0, 0.7, -0.8), (0.3, 1.1, 2.0)):
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
