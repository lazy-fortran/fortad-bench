#!/usr/bin/env python3
"""Independent numerical oracle for the exact set04/lh148 ``toto`` map."""

from __future__ import annotations

import math
import sys
from pathlib import Path


def primal(a: float, b: float, c: float) -> float:
    return a * b * c


def jvp(a: float, b: float, c: float, ad: float, bd: float, cd: float) -> float:
    return ad * b * c + a * bd * c + a * b * cd


def vjp(a: float, b: float, c: float, seed: float) -> tuple[float, float, float]:
    return seed * b * c, seed * a * c, seed * a * b


def run(source: Path | None = None) -> None:
    if source is not None:
        text = source.read_text(encoding="utf-8").lower().replace(" ", "")
        if "subroutinetoto(a,b,c,d)" not in text or "d=a*b*c" not in text:
            raise AssertionError("the pinned exact source is not the selected product case")

    cases = (
        (2.0, -3.0, 0.5, 0.25, -0.5, 1.25),
        (-1.25, 0.75, 4.0, -0.4, 0.2, -0.8),
        (3.5, 2.0, -1.5, 0.6, -0.3, 0.1),
        (-2.0, -1.5, -0.25, 0.2, 0.7, -0.9),
    )
    epsilon = 1.0e-6
    seed = 0.73
    for a, b, c, ad, bd, cd in cases:
        tangent = jvp(a, b, c, ad, bd, cd)
        plus = primal(a + epsilon * ad, b + epsilon * bd, c + epsilon * cd)
        minus = primal(a - epsilon * ad, b - epsilon * bd, c - epsilon * cd)
        finite_difference = (plus - minus) / (2.0 * epsilon)
        if not math.isclose(tangent, finite_difference, rel_tol=2.0e-8, abs_tol=2.0e-8):
            raise AssertionError("central-difference JVP mismatch")

        a_bar, b_bar, c_bar = vjp(a, b, c, seed)
        lhs = a_bar * ad + b_bar * bd + c_bar * cd
        rhs = seed * tangent
        if not math.isclose(lhs, rhs, rel_tol=2.0e-10, abs_tol=2.0e-10):
            raise AssertionError("adjoint identity mismatch")
        if not math.isfinite(primal(a, b, c)):
            raise AssertionError("non-finite primal value")

    print("oracle_behavioral_cases: 4")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]) if len(sys.argv) > 1 else None)
