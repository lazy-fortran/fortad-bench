#!/usr/bin/env python3
"""Independent semantic oracle for v421's legal helper domain and boundary."""

from __future__ import annotations


def g_value(u: tuple[float, float]) -> tuple[float, tuple[float, float]]:
    """Model g on its declared two-element domain."""
    if len(u) != 2:
        raise ValueError("g requires a two-element array")
    z = u[0] * u[0]
    return z, (u[0], z)


def g_jvp(u: tuple[float, float], du: tuple[float, float]) -> tuple[float, tuple[float, float]]:
    if len(u) != 2 or len(du) != 2:
        raise ValueError("g JVP requires two-element primal and tangent arrays")
    dz = 2.0 * u[0] * du[0]
    return dz, (du[0], dz)


def g_vjp(u: tuple[float, float], seed_z: float, seed_u2: float) -> tuple[float, float]:
    if len(u) != 2:
        raise ValueError("g VJP requires a two-element primal array")
    return (2.0 * u[0] * (seed_z + seed_u2), 0.0)


def main() -> None:
    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for u0, u1, du0, du1, seed_z, seed_u2 in (
        (1.25, -0.75, 0.2, -0.4, 0.6, -0.1),
        (-0.4, 2.1, -0.7, 0.3, -1.2, 0.5),
        (3.0, 0.125, 0.01, 0.09, 2.5, -0.8),
    ):
        u = (u0, u1)
        du = (du0, du1)
        eps = 1.0e-6
        fd = (g_value((u0 + eps, u1))[0] - g_value((u0 - eps, u1))[0]) / (2.0 * eps)
        max_fd_error = max(max_fd_error, abs(fd - 2.0 * u0))

        lhs = seed_z * g_jvp(u, du)[0] + seed_u2 * g_jvp(u, du)[1][1]
        grad = g_vjp(u, seed_z, seed_u2)
        rhs = grad[0] * du0 + grad[1] * du1
        max_adjoint_error = max(max_adjoint_error, abs(lhs - rhs))

    # The exact top call is (/y/), while g's explicit-shape dummy is dimension(2).
    exact_actual = (2.0,)
    if len(exact_actual) == 2:
        raise AssertionError("the exact top actual unexpectedly satisfies g's domain")
    try:
        g_value(exact_actual)  # type: ignore[arg-type]
    except ValueError as error:
        if str(error) != "g requires a two-element array":
            raise
    else:
        raise AssertionError("the independent model accepted the invalid exact actual")

    if max_fd_error > 3.0e-6 or max_adjoint_error > 1.0e-12:
        raise SystemExit("oracle failure")
    print("oracle_status: pass invalid-top-actual-shape")
    print(f"legal_domain_finite_difference_max_error: {max_fd_error:.16e}")
    print(f"legal_domain_adjoint_identity_residual: {max_adjoint_error:.16e}")
    print("exact_top_actual_length: 1")
    print("required_g_dummy_length: 2")


if __name__ == "__main__":
    main()
