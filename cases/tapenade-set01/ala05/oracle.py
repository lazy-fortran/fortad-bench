#!/usr/bin/env python3
"""Independent behavioral oracle for exact Tapenade set01/ala05 arithmetic."""

from __future__ import annotations

import argparse
import math
import re
import struct
from pathlib import Path


SLICES = 50
EPSILON = 1.0e-10


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def default_real(value: float) -> float:
    """Round a default-real expression as the exact source does."""
    return struct.unpack("f", struct.pack("f", value))[0]


def source_inventory(source: Path) -> None:
    text = source.read_text(encoding="latin-1").lower()
    compact = re.sub(r"\s+", "", text)
    required = (
        "programmain",
        "callnfp(x,y)",
        "subroutinenfp(x,y)",
        "slices=50",
        "z=1.0",
        "epsilon=1.d-10",
        "!$adfp-loopzadj_residual=1.0e-30",
        "dowhile((oldz-z)*(oldz-z)>epsilon)",
        "z=0.75d0*z+0.25d0*x/z",
        "y=y+z/slices",
    )
    for fragment in required:
        require(fragment in compact, f"exact ala05 source inventory missing {fragment!r}")
    require(compact.count("subroutinenfp(x,y)") == 1, "NFP entry point is not unique")
    print("oracle_source_shape: exact NFP warm-start inventory pass")


def nfp_value(x: float) -> tuple[float, float, float, list[int]]:
    """Model the exact arithmetic, including default-real 1.0/slices."""
    increment = default_real(1.0 / SLICES)
    y = 0.0
    z = 1.0
    counts: list[int] = []
    for _ in range(SLICES):
        x += increment
        oldz = z + 1.0
        iterations = 0
        while (oldz - z) * (oldz - z) > EPSILON:
            oldz = z
            z = 0.75 * z + 0.25 * x / z
            iterations += 1
            require(iterations < 10_000, "independent fixed-point model did not terminate")
        y += z / SLICES
        counts.append(iterations)
    require(math.isfinite(y) and math.isfinite(x) and math.isfinite(z), "primal model is non-finite")
    return y, x, z, counts


def nfp_jvp(x: float, dx: float) -> tuple[float, list[int]]:
    """Differentiate the finite source iteration sequence by hand."""
    increment = default_real(1.0 / SLICES)
    z = 1.0
    dz = 0.0
    dy = 0.0
    counts: list[int] = []
    for _ in range(SLICES):
        x += increment
        oldz = z + 1.0
        iterations = 0
        while (oldz - z) * (oldz - z) > EPSILON:
            oldz = z
            dz = 0.75 * dz + 0.25 * (dx / z - x * dz / z**2)
            z = 0.75 * z + 0.25 * x / z
            iterations += 1
        dy += dz / SLICES
        counts.append(iterations)
    return dy, counts


def nfp_vjp(x: float, seed: float) -> float:
    """Reverse the same scalar recurrence independently of either AD engine."""
    increment = default_real(1.0 / SLICES)
    z = 1.0
    states: list[list[tuple[float, float]]] = []
    for _ in range(SLICES):
        x += increment
        oldz = z + 1.0
        slice_states: list[tuple[float, float]] = []
        while (oldz - z) * (oldz - z) > EPSILON:
            slice_states.append((z, x))
            oldz = z
            z = 0.75 * z + 0.25 * x / z
        states.append(slice_states)

    bar_x = 0.0
    bar_z = 0.0
    for slice_states in reversed(states):
        bar_z += seed / SLICES
        for old_z, slice_x in reversed(slice_states):
            bar_x += bar_z * 0.25 / old_z
            bar_z *= 0.75 - 0.25 * slice_x / old_z**2
    return bar_x


def semantic_checks() -> None:
    x = 5.0
    value, final_x, final_z, counts = nfp_value(x)
    require(len(counts) == SLICES and sum(counts) == 457, "unexpected warm-start iteration count")
    require(math.isclose(final_x, 5.999999977648258, rel_tol=0.0, abs_tol=1.0e-15), "unexpected final x")
    require(math.isclose(value, 2.346524320087252, rel_tol=0.0, abs_tol=2.0e-15), "unexpected primal value")
    require(math.isclose(final_z, 2.4494817556864, rel_tol=0.0, abs_tol=2.0e-15), "unexpected final z")
    print(f"oracle_primal: value={value:.15g} slices={len(counts)} iterations={sum(counts)} pass")

    dx = 0.37
    analytic, analytic_counts = nfp_jvp(x, dx)
    require(analytic_counts == counts, "JVP changed the source iteration path")
    h = 1.0e-6
    plus = nfp_value(x + h * dx)[0]
    minus = nfp_value(x - h * dx)[0]
    finite_difference = (plus - minus) / (2.0 * h)
    require(
        math.isclose(analytic, finite_difference, rel_tol=2.0e-7, abs_tol=2.0e-10),
        f"JVP central-difference mismatch: {analytic} != {finite_difference}",
    )
    print("oracle_jvp_finite_difference: pass")

    seed = 0.83
    gradient = nfp_vjp(x, seed)
    require(
        math.isclose(seed * analytic, gradient * dx, rel_tol=0.0, abs_tol=2.0e-12),
        f"VJP dot-product mismatch: {seed * analytic} != {gradient * dx}",
    )
    print("oracle_vjp_dot_product: pass")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    source_inventory(parser.parse_args().source.resolve())
    semantic_checks()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
