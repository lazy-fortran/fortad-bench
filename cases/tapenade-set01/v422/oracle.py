#!/usr/bin/env python3
"""Independent semantic oracle for the defined v422 state mutation.

The Fortran function result is intentionally not modeled: the exact source
never assigns it.  This oracle checks only the defined observable mutation
``t <- t**2*u`` with a hand JVP, central differences, and hand VJP.
"""

from __future__ import annotations

import math
import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v422" / "program.f90"


def primal(t: float, u: float) -> float:
    return t * t * u


def jvp(t: float, u: float, dt: float, du: float) -> float:
    return 2.0 * t * u * dt + t * t * du


def vjp(t: float, u: float, cotangent: float) -> tuple[float, float]:
    return cotangent * 2.0 * t * u, cotangent * t * t


def main() -> None:
    source_text = SOURCE.read_text(encoding="utf-8")
    if not re.search(r"(?im)^\s*t\s*=\s*t\s*\*\s*t\s*\*\s*u\s*$", source_text):
        raise AssertionError("the exact source no longer contains t <- t**2*u")
    if re.search(r"(?im)^\s*f4\s*=", source_text):
        raise AssertionError("the exact source unexpectedly assigns the f4 result")

    t, u = 1.25, 2.5
    dt, du = 0.3, -0.2
    cotangent = 0.7
    epsilon = 1.0e-6
    finite_difference = (
        primal(t + epsilon * dt, u + epsilon * du)
        - primal(t - epsilon * dt, u - epsilon * du)
    ) / (2.0 * epsilon)
    tangent = jvp(t, u, dt, du)
    finite_difference_error = abs(finite_difference - tangent)
    gradient_t, gradient_u = vjp(t, u, cotangent)
    adjoint_left = cotangent * tangent
    adjoint_right = gradient_t * dt + gradient_u * du
    adjoint_residual = abs(adjoint_left - adjoint_right)

    assert math.isfinite(finite_difference_error)
    assert math.isfinite(adjoint_residual)
    assert finite_difference_error < 1.0e-9, finite_difference_error
    assert adjoint_residual < 1.0e-12, adjoint_residual
    print(
        "oracle_status: pass "
        f"mutation={primal(t, u):.6g} "
        f"finite_difference_max_error={finite_difference_error:.3e} "
        f"adjoint_identity_residual={adjoint_residual:.3e} "
        "function_result=undefined"
    )


if __name__ == "__main__":
    main()
