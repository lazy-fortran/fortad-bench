"""Independent visible-map oracle for set02/v103's exact COMMON case."""

from __future__ import annotations


def value(x: list[float]) -> list[float]:
    return [2.0 * item for item in x]


def jvp(dx: list[float]) -> list[float]:
    return [2.0 * item for item in dx]


def dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def main() -> None:
    max_fd = 0.0
    max_adjoint = 0.0
    for x, dx, seed in (
        ([1.0, -2.0, 3.0, -4.0], [0.2, 0.4, -0.3, 0.7], [1.0, -0.5, 0.8, 1.2]),
        ([-0.4, 0.1, 2.5, 3.0], [-0.7, 0.2, 0.6, -0.1], [-1.2, 0.3, 0.4, -0.8]),
    ):
        eps = 1.0e-6
        plus = value([a + eps*b for a, b in zip(x, dx)])
        minus = value([a - eps*b for a, b in zip(x, dx)])
        finite_difference = [(a - b) / (2.0 * eps) for a, b in zip(plus, minus)]
        tangent = jvp(dx)
        max_fd = max(max_fd, max(abs(a-b) for a, b in zip(finite_difference, tangent)))
        max_adjoint = max(max_adjoint, abs(dot(seed, tangent) - dot(value(seed), dx)))
    assert max_fd < 1.0e-9, max_fd
    assert max_adjoint < 1.0e-14, max_adjoint
    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max_fd:.16e}")
    print(f"adjoint_identity_max_error: {max_adjoint:.16e}")
    print("visible_map: y = 2*x; COMMON state is not ported")


if __name__ == "__main__":
    main()
