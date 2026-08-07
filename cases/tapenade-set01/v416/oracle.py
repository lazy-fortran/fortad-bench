"""Independent numerical oracle for the bounded v416 recurrence.

This model is intentionally separate from Fortran, Tapenade, and FortAD.  It
checks the matrix recurrence on the stated domain, central differences, and
the JVP/VJP adjoint identity.
"""

from __future__ import annotations

import math


def matrix_11(nm_ha: int, tm_ha: float) -> float:
    if nm_ha < 2 or tm_ha == 0.0 or not math.isfinite(tm_ha):
        raise ValueError("outside bounded v416 domain")
    matrix = [[0.0 for _ in range(nm_ha)] for _ in range(nm_ha)]
    for _ in range(2):
        matrix[0][1] = 0.0  # Fortran integer division makes 1/5/2. equal zero.
        for j_ha in range(1, nm_ha):
            matrix[j_ha - 1][j_ha - 1] = 1.0
            matrix[j_ha - 1][j_ha] = 1.0 / 2.0 / tm_ha
            matrix[j_ha][j_ha - 1] = -1.0 / 2.0 / tm_ha
        matrix[nm_ha - 1][nm_ha - 1] = 1.0 + 1.0 / tm_ha
        matrix[nm_ha - 1][nm_ha - 2] = -1.0 / tm_ha
    return matrix[0][0]


def value(x: float, nm_ha: int, tm_ha: float) -> float:
    return x * x * matrix_11(nm_ha, tm_ha)


def jvp(x: float, dx: float, nm_ha: int, tm_ha: float, dtm_ha: float) -> float:
    del dtm_ha  # matrix_11 is constant in tm_ha throughout the checked domain.
    return 2.0 * x * dx * matrix_11(nm_ha, tm_ha)


def vjp(x: float, nm_ha: int, tm_ha: float, seed: float) -> tuple[float, float]:
    return 2.0 * x * seed * matrix_11(nm_ha, tm_ha), 0.0


def main() -> None:
    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for x, dx, nm_ha, tm_ha, dtm_ha, seed in (
        (1.25, -0.2, 2, 0.75, 0.4, 0.6),
        (-0.4, 0.3, 3, -1.5, -0.7, -1.2),
        (2.0, 0.05, 5, 3.0, 0.2, 2.5),
    ):
        if matrix_11(nm_ha, tm_ha) != 1.0:
            raise SystemExit("matrix recurrence lost MC_ha(1,1)=1 on the domain")
        epsilon = 1.0e-6
        fd_x = (
            value(x + epsilon * dx, nm_ha, tm_ha + epsilon * dtm_ha)
            - value(x - epsilon * dx, nm_ha, tm_ha - epsilon * dtm_ha)
        ) / (2.0 * epsilon)
        tangent = jvp(x, dx, nm_ha, tm_ha, dtm_ha)
        max_fd_error = max(max_fd_error, abs(fd_x - tangent))

        x_b, tm_ha_b = vjp(x, nm_ha, tm_ha, seed)
        lhs = seed * tangent
        rhs = x_b * dx + tm_ha_b * dtm_ha
        max_adjoint_error = max(max_adjoint_error, abs(lhs - rhs))

    if max_fd_error > 1.0e-7 or max_adjoint_error > 1.0e-12:
        raise SystemExit(
            f"oracle failure fd={max_fd_error:.3e} adjoint={max_adjoint_error:.3e}"
        )
    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max_fd_error:.16e}")
    print(f"adjoint_identity_residual: {max_adjoint_error:.16e}")
    print("domain_check: nm_ha>=2 and finite nonzero Tm_ha")


if __name__ == "__main__":
    main()
