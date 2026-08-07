#!/usr/bin/env python3
"""Independent closed-form oracle for the set02/lh163 map."""

from __future__ import annotations

import math
import sys
from pathlib import Path


def primal(v: float, p: float, q: float) -> tuple[float, float, float]:
    s = q * v
    return p * p, 3.0 * p * p, s


def jvp(v: float, p: float, q: float, vd: float, pd: float, qd: float) -> float:
    del p, pd
    return qd * v + q * vd


def run(source: Path) -> None:
    text = source.read_text(encoding="utf-8").lower().replace(" ", "")
    for fragment in ("subroutinetest(v,p,q,s)", "s=q*v", "v=p*p", "q=3.0*v"):
        if fragment not in text:
            raise AssertionError(f"exact source is missing {fragment}")
    cases = ((2.0, 1.5, -0.75, -0.3, 0.8, 0.4),
             (-1.25, 0.4, 2.5, 0.7, -0.2, -0.6),
             (3.0, -1.1, 0.2, -0.4, 0.3, 0.9))
    for v, p, q, vd, pd, qd in cases:
        _, _, s = primal(v, p, q)
        tangent = jvp(v, p, q, vd, pd, qd)
        epsilon = 1.0e-6
        plus = primal(v + epsilon * vd, p + epsilon * pd, q + epsilon * qd)[2]
        minus = primal(v - epsilon * vd, p - epsilon * pd, q - epsilon * qd)[2]
        finite_difference = (plus - minus) / (2.0 * epsilon)
        if not math.isclose(tangent, finite_difference, rel_tol=2e-6, abs_tol=2e-6):
            raise AssertionError("central-difference JVP mismatch")
        seed = 0.65
        v_bar, p_bar, q_bar = seed * q, 0.0, seed * v
        if not math.isclose(v_bar * vd + p_bar * pd + q_bar * qd, seed * tangent,
                            rel_tol=2e-7, abs_tol=2e-7):
            raise AssertionError("adjoint identity mismatch")
        assert math.isfinite(s)
    print("oracle_behavioral_cases: 3")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).with_name("program.f"))
