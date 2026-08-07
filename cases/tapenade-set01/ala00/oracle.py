#!/usr/bin/env python3
"""Independent semantic oracle for the exact ala00 fixed-point procedure."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_inventory(source: Path) -> None:
    text = source.read_text(encoding="latin-1").lower()
    compact = re.sub(r"\s+", "", text)
    required = (
        "programtest",
        "callroot(x,y,initial)",
        "subroutineroot(x,y,initial)",
        "c$adfp-loopz",
        "dowhile((z-oz)**2.ge.1.e-10)",
        "oz=z",
        "z=z+x",
        "z=2.0/z",
        "y=z*x",
        "print*,\"#iterations:\",i",
    )
    for fragment in required:
        require(fragment in compact, f"exact ala00 source inventory missing {fragment!r}")
    require(compact.count("subroutineroot(x,y,initial)") == 1, "root entry point is not unique")
    print("oracle_source_shape: exact root fixed-point and print inventory pass")


def root_map(x: float, initial: float) -> tuple[float, int, float]:
    """Reproduce the source arithmetic without importing or transforming it."""
    z = initial
    oz = z + 1.0
    iterations = 0
    while (z - oz) ** 2 >= 1.0e-10:
        oz = z
        z = z + x
        z = 2.0 / z
        iterations += 1
        require(iterations < 10_000, "independent fixed-point model did not terminate")
    return z * x, iterations, z


def root_jvp(x: float, initial: float, dx: float, dinitial: float) -> tuple[float, int]:
    """Differentiate the same finite iteration sequence by hand."""
    z = initial
    dz = dinitial
    oz = z + 1.0
    iterations = 0
    while (z - oz) ** 2 >= 1.0e-10:
        oz = z
        z = z + x
        dz = dz + dx
        dz = -(2.0 * dz / z**2)
        z = 2.0 / z
        iterations += 1
        require(iterations < 10_000, "independent JVP model did not terminate")
    return x * dz + z * dx, iterations


def root_vjp(x: float, initial: float, seed: float) -> tuple[float, float]:
    """Reverse the same scalar recurrence independently of Tapenade/FortAD."""
    z = initial
    oz = z + 1.0
    states: list[float] = []
    while (z - oz) ** 2 >= 1.0e-10:
        states.append(z)
        oz = z
        z = 2.0 / (z + x)
        require(len(states) < 10_000, "independent VJP model did not terminate")

    bar_z = seed * x
    bar_x = seed * z
    for old_z in reversed(states):
        reciprocal_derivative = -2.0 / (old_z + x) ** 2
        bar_w = bar_z * reciprocal_derivative
        bar_z = bar_w
        bar_x += bar_w
    return bar_x, bar_z


def semantic_checks() -> None:
    x, initial = 1.13, 2.7
    direction = (-0.31, 0.47)
    seed = 0.83
    value, iterations, z = root_map(x, initial)
    require(iterations > 0 and math.isfinite(value) and math.isfinite(z), "fixed-point map invalid")
    require(abs(z - 2.0 / (z + x)) < 1.0e-4, "fixed-point map did not reach its source tolerance")
    print(f"oracle_primal: finite fixed-point map pass iterations={iterations}")

    analytic, analytic_iterations = root_jvp(x, initial, *direction)
    require(analytic_iterations == iterations, "central-difference point changed iteration count")
    h = 1.0e-6
    plus = root_map(x + h * direction[0], initial + h * direction[1])[0]
    minus = root_map(x - h * direction[0], initial - h * direction[1])[0]
    finite_difference = (plus - minus) / (2.0 * h)
    require(math.isclose(analytic, finite_difference, rel_tol=2.0e-7, abs_tol=2.0e-8),
            f"JVP central difference mismatch: {analytic} != {finite_difference}")
    print("oracle_jvp: hand finite-iteration JVP agrees with central difference")

    gradient = root_vjp(x, initial, seed)
    tangent = analytic
    cotangent = gradient[0] * direction[0] + gradient[1] * direction[1]
    require(math.isclose(seed * tangent, cotangent, rel_tol=0.0, abs_tol=2.0e-12),
            f"VJP dot-product identity mismatch: {seed * tangent} != {cotangent}")
    print("oracle_vjp: hand reverse recurrence passes dot-product identity")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    source_inventory(parser.parse_args().source.resolve())
    semantic_checks()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
