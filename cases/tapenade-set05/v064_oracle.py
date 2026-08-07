#!/usr/bin/env python3
"""Independent hand, finite-difference, and adjoint oracle for v064."""

from __future__ import annotations

import math
import sys
from pathlib import Path


def primal(ptab: float) -> float:
    return ptab + 1.0


def jvp(ptab_d: float) -> float:
    return ptab_d


def vjp(value_b: float) -> float:
    return value_b


def run(source: Path | None = None) -> None:
    if source is not None:
        text = source.read_text(encoding="utf-8").lower().replace(" ", "")
        if "subroutinemppsum_real(ptab)" not in text or "ptab=ptab+1.0" not in text:
            raise AssertionError("the pinned exact source is not the selected v064 closure")

    cases = ((3.25, -0.75), (-2.5, 4.0), (0.125, 1.1), (9.0, -3.5))
    epsilon = 1.0e-6
    value_b = 0.8
    for ptab, ptab_d in cases:
        tangent = jvp(ptab_d)
        plus = primal(ptab + epsilon * ptab_d)
        minus = primal(ptab - epsilon * ptab_d)
        finite_difference = (plus - minus) / (2.0 * epsilon)
        if not math.isclose(tangent, finite_difference, rel_tol=1.0e-9, abs_tol=1.0e-9):
            raise AssertionError("central-difference JVP mismatch")
        ptab_b = vjp(value_b)
        if not math.isclose(ptab_b * ptab_d, value_b * tangent,
                           rel_tol=1.0e-12, abs_tol=1.0e-12):
            raise AssertionError("adjoint identity mismatch")
    print("oracle_behavioral_cases: 4")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]) if len(sys.argv) > 1 else None)
