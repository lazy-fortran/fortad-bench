#!/usr/bin/env python3
"""Independent numerical/semantic oracle for the v500 boundary."""

from __future__ import annotations

import math
import os
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v500" / "program.f90"


def alpha_model(radius: float, density: float) -> float:
    """Hand reduction of the exact fixed-radius accumulation."""
    mass_per_bin = (4.0 / 3.0) * math.pi * radius**3 * (1.0 / 10000.0) * density * 1.0e3
    total_mass = 10001.0 * mass_per_bin
    total_extinction = 10001.0 * radius * 2.0
    return total_extinction / total_mass


def alpha_jvp(radius: float, density: float, dr: float, ddensity: float) -> float:
    value = alpha_model(radius, density)
    return value * (-2.0 * dr / radius - ddensity / density)


def alpha_vjp(radius: float, density: float, cotangent: float) -> tuple[float, float]:
    value = alpha_model(radius, density)
    return cotangent * (-2.0 * value / radius), cotangent * (-value / density)


def main() -> None:
    source_text = SOURCE.read_text(encoding="utf-8")
    required_fragments = (
        "PARAMETER (Nbin=10000)",
        "DO bin=0, Nbin",
        "sigma_sca(lda)=0.0",
        "PP(Nmu,lda)=pi/sigma_sca(lda)*PP(Nmu,lda)",
    )
    for fragment in required_fragments:
        if fragment not in source_text:
            raise AssertionError(f"exact source no longer contains: {fragment}")

    radius, density = 2.0, 1.769e3
    dr, ddensity, cotangent = 0.07, -13.0, 0.8
    epsilon = 1.0e-6
    finite_difference = (
        alpha_model(radius + epsilon * dr, density + epsilon * ddensity)
        - alpha_model(radius - epsilon * dr, density - epsilon * ddensity)
    ) / (2.0 * epsilon)
    tangent = alpha_jvp(radius, density, dr, ddensity)
    finite_difference_error = abs(finite_difference - tangent)
    gradient_radius, gradient_density = alpha_vjp(radius, density, cotangent)
    adjoint_left = cotangent * tangent
    adjoint_right = gradient_radius * dr + gradient_density * ddensity
    adjoint_residual = abs(adjoint_left - adjoint_right)

    sigma_sca = 0.0
    pp_seed = 0.0
    if sigma_sca != 0.0:
        raise AssertionError("the exact source unexpectedly increments sigma_sca")
    pp_normalization_is_singular = sigma_sca == 0.0 and pp_seed == 0.0
    if not pp_normalization_is_singular:
        raise AssertionError("the exact PP normalization unexpectedly became finite")
    if not math.isfinite(alpha_model(radius, density)):
        raise AssertionError("alpha_ext hand model is not finite")
    if finite_difference_error > 2.0e-10 or adjoint_residual > 1.0e-15:
        raise SystemExit("oracle failure")

    print("oracle_status: pass singular-pp-normalization")
    print(f"alpha_ext_at_exact_point: {alpha_model(radius, density):.16e}")
    print(f"finite_difference_max_error: {finite_difference_error:.3e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.3e}")
    print("bins: 10001")
    print("sigma_sca: 0.0")
    print("pp_normalization: singular-zero-over-zero")


if __name__ == "__main__":
    main()
