#!/usr/bin/env python3
"""Independent hand, finite-difference, and adjoint oracle for v065."""

from __future__ import annotations

import math
import sys
from pathlib import Path


def primal(ptab: list[float], cst: float) -> list[float]:
    return [item * cst for item in ptab]


def jvp(ptab_d: list[float], cst: float) -> list[float]:
    return [item_d * cst for item_d in ptab_d]


def vjp(cst: float, value_b: list[float]) -> list[float]:
    return [seed * cst for seed in value_b]


def dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def run(source: Path | None = None) -> None:
    if source is not None:
        text = source.read_text(encoding="utf-8").lower().replace(" ", "")
        required = ("subroutinemppsum_real2(ptab,cst,str)",
                    "ptab(ji,1)=ptab(ji,1)*cst")
        if not all(fragment in text for fragment in required):
            raise AssertionError("the pinned exact source is not the selected v065 closure")

    cases = (([0.25 * i - 1.5 for i in range(1, 11)],
              [(-1.0) ** i * 0.1 * i for i in range(1, 11)], 1.75),
             ([2.0 - 0.3 * i for i in range(10)],
              [0.07 * (i + 1) for i in range(10)], -0.8),
             ([-1.25 + 0.4 * i for i in range(10)],
              [0.11 - 0.02 * i for i in range(10)], 2.5),
             ([0.5 * (i - 4) for i in range(10)],
              [0.03 * (i - 3) for i in range(10)], 0.125))
    epsilon = 1.0e-6
    value_b = [0.05 * i - 0.2 for i in range(1, 11)]
    for ptab, ptab_d, cst in cases:
        tangent = jvp(ptab_d, cst)
        plus = primal([item + epsilon * direction for item, direction in zip(ptab, ptab_d)],
                      cst)
        minus = primal([item - epsilon * direction for item, direction in zip(ptab, ptab_d)],
                      cst)
        finite_difference = [(a - b) / (2.0 * epsilon) for a, b in zip(plus, minus)]
        if not all(math.isclose(a, b, rel_tol=1.0e-9, abs_tol=1.0e-9)
                   for a, b in zip(tangent, finite_difference)):
            raise AssertionError("central-difference JVP mismatch")
        ptab_b = vjp(cst, value_b)
        if not math.isclose(dot(ptab_b, ptab_d),
                            dot(value_b, tangent), rel_tol=1.0e-12, abs_tol=1.0e-12):
            raise AssertionError("adjoint identity mismatch")
    print("oracle_behavioral_cases: 4")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]) if len(sys.argv) > 1 else None)
