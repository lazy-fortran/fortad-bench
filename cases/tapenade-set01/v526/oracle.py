"""Independent SING3 oracle for the bounded one-element port."""

from __future__ import annotations

import math
import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v526" / "program.f90"


def value(dxp: float, dyp: float, epaisseur: int) -> float:
    return dxp * dxp if epaisseur == 1 else dyp


def jvp(dxp: float, dyp: float, ddxp: float, ddyp: float, epaisseur: int) -> float:
    return 2.0 * dxp * ddxp if epaisseur == 1 else ddyp


def vjp(dxp: float, dyp: float, seed: float, epaisseur: int) -> tuple[float, float]:
    return (seed * 2.0 * dxp, 0.0) if epaisseur == 1 else (0.0, seed)


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert re.search(r"(?is)subroutine\s+singu?3\b.*?if\s*\(\s*epaisseur_seuil\s*==\s*1\s*\).*?dyp\s*=\s*dxp\s*\*\s*dxp", source)

    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for dxp, dyp, ddxp, ddyp, seed, epaisseur in (
        (1.25, -0.75, -0.3, 0.4, 0.7, 1),
        (-0.4, 2.1, 0.2, -0.6, -1.2, 1),
        (1.25, -0.75, -0.3, 0.4, 0.7, 0),
    ):
        epsilon = 1.0e-6
        finite_difference = (
            value(dxp + epsilon * ddxp, dyp + epsilon * ddyp, epaisseur)
            - value(dxp - epsilon * ddxp, dyp - epsilon * ddyp, epaisseur)
        ) / (2.0 * epsilon)
        tangent = jvp(dxp, dyp, ddxp, ddyp, epaisseur)
        max_fd_error = max(max_fd_error, abs(finite_difference - tangent))
        gradient = vjp(dxp, dyp, seed, epaisseur)
        max_adjoint_error = max(
            max_adjoint_error,
            abs(seed * tangent - (gradient[0] * ddxp + gradient[1] * ddyp)),
        )

    assert math.isfinite(max_fd_error)
    assert math.isfinite(max_adjoint_error)
    assert max_fd_error < 1.0e-9, max_fd_error
    assert max_adjoint_error < 1.0e-12, max_adjoint_error
    assert value(1.25, -0.75, 0) == -0.75
    print("oracle_status: pass")
    print(f"finite_difference_max_error: {max_fd_error:.16e}")
    print(f"adjoint_identity_residual: {max_adjoint_error:.16e}")
    print(f"active_value: {value(1.25, -0.75, 1):.16e}")
    print("inactive_branch: dyp unchanged")


if __name__ == "__main__":
    main()
