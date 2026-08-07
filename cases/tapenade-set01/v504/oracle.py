"""Independent oracle for v504's bounded returned observable.

The oracle intentionally does not read Fortran or invoke Tapenade/FortAD.  It
models only the explicitly bounded port contract: top = 4*r[0]*r[1], with s
inactive, and checks finite differences plus the JVP/VJP adjoint identity.
"""

from __future__ import annotations

import math


def value(r1: float, r2: float) -> float:
    return (2.0 * r1) * (2.0 * r2)


def jvp(r1: float, r2: float, dr1: float, dr2: float) -> float:
    return 4.0 * (dr1 * r2 + r1 * dr2)


def vjp(r1: float, r2: float, seed: float) -> tuple[float, float]:
    return 4.0 * r2 * seed, 4.0 * r1 * seed


def main() -> None:
    epsilon = 1.0e-6
    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for r1, r2, dr1, dr2, ds1, ds2, seed in (
        (3.0, 2.0, -0.25, 0.5, 1.5, -2.0, 1.75),
        (-1.25, 0.75, 0.4, -0.3, -0.5, 0.25, -0.8),
        (2.5, -3.0, -1.2, 0.125, 2.0, 1.0, 0.6),
    ):
        values = (r1, r2, dr1, dr2, ds1, ds2, seed)
        if not all(math.isfinite(item) for item in values):
            raise SystemExit("oracle input outside finite bounded domain")
        numerical = (
            value(r1 + epsilon * dr1, r2 + epsilon * dr2)
            - value(r1 - epsilon * dr1, r2 - epsilon * dr2)
        ) / (2.0 * epsilon)
        tangent = jvp(r1, r2, dr1, dr2)
        max_fd_error = max(max_fd_error, abs(numerical - tangent))

        r1_b, r2_b = vjp(r1, r2, seed)
        lhs = seed * tangent
        rhs = r1_b * dr1 + r2_b * dr2 + 0.0 * ds1 + 0.0 * ds2
        max_adjoint_error = max(max_adjoint_error, abs(lhs - rhs))

    assert max_fd_error < 1.0e-8, max_fd_error
    assert max_adjoint_error < 1.0e-12, max_adjoint_error
    print("observable: top = 4*r(1)*r(2); s derivative = 0")
    print(f"finite_difference_max_error: {max_fd_error:.3e}")
    print(f"adjoint_identity_residual: {max_adjoint_error:.3e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
