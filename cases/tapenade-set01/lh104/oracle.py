#!/usr/bin/env python3
"""Independent behavioral oracle for the exact lh104 mathematical map.

The upstream source is intentionally not parsed here. This model is only a
bounded semantic oracle for branch-sensitive primal/JVP/VJP behavior; it is
not a repaired source port.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path


def primal(values: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    a, b, c, d = values
    scaled_a = 3.8 * a
    if scaled_a > 10.0:
        b = scaled_a * b
    c = scaled_a * c
    if scaled_a < 10.0:
        d = scaled_a * d
    return scaled_a, b, c, d


def jvp(
    values: tuple[float, float, float, float],
    direction: tuple[float, float, float, float],
) -> tuple[float, float, float, float]:
    a, b, c, d = values
    da, db, dc, dd = direction
    scaled_a = 3.8 * a
    dscaled_a = 3.8 * da
    if scaled_a > 10.0:
        db_out = dscaled_a * b + scaled_a * db
    else:
        db_out = db
    dc_out = dscaled_a * c + scaled_a * dc
    if scaled_a < 10.0:
        dd_out = dscaled_a * d + scaled_a * dd
    else:
        dd_out = dd
    return dscaled_a, db_out, dc_out, dd_out


def vjp(
    values: tuple[float, float, float, float],
    seed: tuple[float, float, float, float],
) -> tuple[float, float, float, float]:
    a, b, c, d = values
    seed_a, seed_b, seed_c, seed_d = seed
    scaled_a = 3.8 * a
    scaled_a_bar = 0.0
    if scaled_a > 10.0:
        b_bar = scaled_a * seed_b
        scaled_a_bar += b * seed_b
    else:
        b_bar = seed_b
    c_bar = scaled_a * seed_c
    scaled_a_bar += c * seed_c
    if scaled_a < 10.0:
        d_bar = scaled_a * seed_d
        scaled_a_bar += d * seed_d
    else:
        d_bar = seed_d
    a_bar = 3.8 * seed_a + 3.8 * scaled_a_bar
    return a_bar, b_bar, c_bar, d_bar


def close(left: tuple[float, ...], right: tuple[float, ...], tol: float = 2.0e-5) -> bool:
    return all(math.isclose(x, y, rel_tol=tol, abs_tol=tol) for x, y in zip(left, right))


def finite_difference(
    values: tuple[float, float, float, float],
    direction: tuple[float, float, float, float],
    step: float = 1.0e-6,
) -> tuple[float, float, float, float]:
    plus = tuple(x + step * dx for x, dx in zip(values, direction))
    minus = tuple(x - step * dx for x, dx in zip(values, direction))
    return tuple((x_plus - x_minus) / (2.0 * step) for x_plus, x_minus in zip(primal(plus), primal(minus)))


def run(source_dir: Path | None = None) -> int:
    # Keep the source argument in the interface used by the bench runners, but
    # deliberately do not read it: this is an independent behavioral oracle.
    del source_dir
    branch_cases = [
        ((4.0, 2.0, 3.0, 5.0), (0.2, -0.3, 0.4, -0.5)),
        ((1.0, 2.0, 3.0, 5.0), (0.2, -0.3, 0.4, -0.5)),
    ]
    for values, _direction in branch_cases:
        if not math.isclose(primal(values)[0], 3.8 * values[0], rel_tol=0.0, abs_tol=1.0e-12):
            raise AssertionError("primal scaling failed")
    print("oracle_branch_paths: pass")

    for values, direction in branch_cases:
        analytic = jvp(values, direction)
        numeric = finite_difference(values, direction)
        if not close(analytic, numeric):
            raise AssertionError(f"JVP mismatch: analytic={analytic}, numeric={numeric}")
    print("oracle_jvp_finite_difference: pass")

    seeds = (0.7, -1.1, 0.4, 1.3)
    for values, direction in branch_cases:
        left = sum(seed * tangent for seed, tangent in zip(seeds, jvp(values, direction)))
        right = sum(gradient * dx for gradient, dx in zip(vjp(values, seeds), direction))
        if not math.isclose(left, right, rel_tol=2.0e-5, abs_tol=2.0e-5):
            raise AssertionError(f"VJP identity mismatch: left={left}, right={right}")
    print("oracle_vjp_dot_product: pass")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    argument = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    raise SystemExit(run(argument))
