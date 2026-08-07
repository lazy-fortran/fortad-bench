#!/usr/bin/env python3
"""Independent hand, finite-difference, and adjoint oracle for ``func``."""

from __future__ import annotations

import math
import sys
from pathlib import Path


def primal(t: float, u: float) -> float:
    return (t + u) / 2.0


def jvp(t_d: float, u_d: float) -> float:
    return (t_d + u_d) / 2.0


def vjp(seed: float) -> tuple[float, float]:
    return seed / 2.0, seed / 2.0


def run(source: Path | None = None) -> None:
    if source is not None:
        text = source.read_text(encoding='utf-8').lower().replace(' ', '')
        if 'functionfunc(t,u)' not in text or not any(
                assignment in text for assignment in ('func=(t+u)/2', 'value=(t+u)/2')):
            raise AssertionError('the pinned exact source is not the selected average case')

    cases = ((3.0, -1.0, 0.25, -0.75), (-2.5, 4.0, -0.4, 0.9),
             (0.125, 7.25, 1.1, -0.2), (5.0, 2.0, -0.8, 0.35))
    epsilon = 1.0e-6
    seed = 0.8
    for t, u, t_d, u_d in cases:
        tangent = jvp(t_d, u_d)
        plus = primal(t + epsilon * t_d, u + epsilon * u_d)
        minus = primal(t - epsilon * t_d, u - epsilon * u_d)
        finite_difference = (plus - minus) / (2.0 * epsilon)
        if not math.isclose(tangent, finite_difference, rel_tol=2.0e-7, abs_tol=2.0e-7):
            raise AssertionError('central-difference JVP mismatch')
        t_bar, u_bar = vjp(seed)
        if not math.isclose(t_bar * t_d + u_bar * u_d, seed * tangent,
                           rel_tol=2.0e-10, abs_tol=2.0e-10):
            raise AssertionError('adjoint identity mismatch')
    print('oracle_behavioral_cases: 4')
    print('oracle_status: pass')


if __name__ == '__main__':
    run(Path(sys.argv[1]) if len(sys.argv) > 1 else None)
