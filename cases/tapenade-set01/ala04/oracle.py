#!/usr/bin/env python3
"""Independent arithmetic oracle for the exact ala04 nested recurrences."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path

TOLERANCE = 1.0e-20
MAX_STEPS = 20_000


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_inventory(source: Path) -> None:
    compact = re.sub(r"\s+", "", source.read_text(encoding="latin-1").lower())
    required = (
        "programtest", "subroutinefp2(x,y)", "subroutinetoto(z,x,oz)",
        "real*8x,y,z,t,ox,oz,ot", "c$adfp-loopz", "c$adfp-loopt",
        "dowhile((z-oz)**2.ge.1.e-20)", "calltoto(t,z,ot)",
        "calltoto(z,x,oz)", "z=t*z", "y=z*x",
    )
    for fragment in required:
        require(fragment in compact, f"exact ala04 source inventory missing {fragment!r}")
    require(compact.count("subroutinefp2(x,y)") == 1, "FP2 entry point is not unique")
    require(compact.count("subroutinetoto(z,x,oz)") == 1, "TOTO helper is not unique")
    print("oracle_source_shape: exact nested FP2/TOTO recurrence inventory pass")


def root_map(x: float, initial_z: float = 24.0) -> tuple[float, int, int]:
    """Evaluate the exact finite nested recurrence without either AD engine."""
    z = initial_z
    outer_iterations = 0
    inner_iterations = 0
    while True:
        old_z = z
        t = 17.0
        old_t = t + 1.0
        inner_count = 0
        while (t - old_t) ** 2 >= TOLERANCE:
            old_t = t
            t = 2.0 / (old_t + old_z)
            inner_count += 1
            require(inner_count < MAX_STEPS, "independent inner fixed-point model did not terminate")
        q = 2.0 / (old_z + x)
        z = t * q
        outer_iterations += 1
        inner_iterations += inner_count
        require(outer_iterations < MAX_STEPS, "independent outer fixed-point model did not terminate")
        if (z - old_z) ** 2 < TOLERANCE:
            break
    return z * x, outer_iterations, inner_iterations


def root_jvp(x: float, initial_z: float, dx: float, dinitial_z: float) -> tuple[float, int]:
    """Propagate a hand-written JVP through the same finite loop sequence."""
    z = initial_z
    dz = dinitial_z
    outer_iterations = 0
    while True:
        old_z = z
        dold_z = dz
        t = 17.0
        dt = 0.0
        old_t = t + 1.0
        inner_count = 0
        while (t - old_t) ** 2 >= TOLERANCE:
            old_t = t
            dold_t = dt
            denominator = old_t + old_z
            t = 2.0 / denominator
            dt = -2.0 * (dold_t + dold_z) / denominator**2
            inner_count += 1
            require(inner_count < MAX_STEPS, "independent JVP inner model did not terminate")
        denominator = old_z + x
        q = 2.0 / denominator
        dq = -2.0 * (dold_z + dx) / denominator**2
        z = t * q
        dz = dt * q + t * dq
        outer_iterations += 1
        require(outer_iterations < MAX_STEPS, "independent JVP outer model did not terminate")
        if (z - old_z) ** 2 < TOLERANCE:
            break
    return z * dx + x * dz, outer_iterations


def root_vjp(x: float, initial_z: float, seed: float) -> tuple[float, float]:
    """Reverse a separately recorded scalar recurrence for (x, initial_z)."""
    z = initial_z
    tape: list[tuple[float, float, float, list[float], float]] = []
    while True:
        old_z = z
        t = 17.0
        old_t = t + 1.0
        inner_states: list[float] = []
        while (t - old_t) ** 2 >= TOLERANCE:
            old_t = t
            inner_states.append(old_t)
            t = 2.0 / (old_t + old_z)
            require(len(inner_states) < MAX_STEPS, "independent VJP inner model did not terminate")
        q = 2.0 / (old_z + x)
        z = t * q
        tape.append((old_z, t, q, inner_states, z))
        require(len(tape) < MAX_STEPS, "independent VJP outer model did not terminate")
        if (z - old_z) ** 2 < TOLERANCE:
            break

    bar_x = seed * tape[-1][4]
    bar_z = seed * x
    for old_z, t, q, inner_states, _ in reversed(tape):
        bar_t = bar_z * q
        bar_q = bar_z * t
        denominator = old_z + x
        bar_denominator = -2.0 * bar_q / denominator**2
        bar_old_z = bar_denominator
        bar_x += bar_denominator
        for old_t in reversed(inner_states):
            denominator = old_t + old_z
            bar_denominator = -2.0 * bar_t / denominator**2
            bar_old_z += bar_denominator
            bar_t = bar_denominator
        bar_z = bar_old_z
    return bar_x, bar_z


def semantic_checks() -> None:
    x = 1.0
    initial_z = 24.0
    value, outer_iterations, inner_iterations = root_map(x, initial_z)
    require(math.isfinite(value), "nested fixed-point primal is not finite")
    require(math.isclose(value, 0.9999999999490585, rel_tol=0.0, abs_tol=2.0e-15),
            f"nested fixed-point primal mismatch: {value}")
    require(outer_iterations == 133 and inner_iterations == 10158,
            f"unexpected iteration accounting: outer={outer_iterations} inner={inner_iterations}")
    print(f"oracle_primal: y={value:.16g} outer_iterations={outer_iterations} inner_iterations={inner_iterations}")

    direction = (0.37, -0.23)
    analytic, jvp_iterations = root_jvp(x, initial_z, *direction)
    h = 1.0e-6
    plus = root_map(x + h * direction[0], initial_z + h * direction[1])
    minus = root_map(x - h * direction[0], initial_z - h * direction[1])
    require(plus[1:] == minus[1:] == (outer_iterations, inner_iterations),
            "central-difference points changed the finite loop sequence")
    finite_difference = (plus[0] - minus[0]) / (2.0 * h)
    require(jvp_iterations == outer_iterations, "JVP loop sequence differs from primal")
    require(math.isclose(analytic, finite_difference, rel_tol=2.0e-7, abs_tol=2.0e-10),
            f"JVP central difference mismatch: {analytic} != {finite_difference}")
    print("oracle_jvp: hand nested-recurrence JVP agrees with central difference")

    seed = 0.83
    bar_x, bar_initial_z = root_vjp(x, initial_z, seed)
    lhs = seed * analytic
    rhs = bar_x * direction[0] + bar_initial_z * direction[1]
    require(math.isclose(lhs, rhs, rel_tol=0.0, abs_tol=2.0e-12),
            f"VJP dot-product mismatch: {lhs} != {rhs}")
    print(f"oracle_vjp: hand reverse recurrence passes dot-product identity bar_x={bar_x:.16g} bar_initial_z={bar_initial_z:.16g}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    source_inventory(parser.parse_args().source.resolve())
    semantic_checks()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
