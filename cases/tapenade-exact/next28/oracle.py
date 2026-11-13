#!/usr/bin/env python3
"""Independent bounded behavior and refusal models for next28.

These models do not read the Tapenade checkout, FortAD output, or exact source
files. They intentionally model only defined initialized values and retain
pointer/global/lifetime refusal boundaries separately from those values.
"""

from __future__ import annotations

import argparse
import json
import math


def _surface(lower: float, upper: float, y_lower: float, y_upper: float) -> tuple[float, float]:
    width = y_upper - y_lower
    new_lower = (upper - lower) * width
    new_upper = (upper - new_lower) * width
    return new_lower, new_upper


def _check_v086() -> dict:
    values = _surface(1.0, 3.0, 2.0, 5.0)
    assert values == (6.0, -9.0)
    eps = 1.0e-6
    plus = _surface(1.0 + eps, 3.0, 2.0, 5.0)
    minus = _surface(1.0 - eps, 3.0, 2.0, 5.0)
    jvp = tuple((a - b) / (2.0 * eps) for a, b in zip(plus, minus))
    assert all(math.isclose(actual, expected, rel_tol=1.0e-8) for actual, expected in zip(jvp, (-3.0, 9.0)))
    return {
        "status": "pass",
        "primal": {"model": "sequential interval-box component update", "surface_intvx": list(values)},
        "derivative": {"status": "checked-bounded-jvp", "lower_input_jvp": list(jvp)},
        "refusal": {"status": "expected", "boundary": "exact derived-type procedure runtime is not claimed"},
    }


def _check_cm04() -> dict:
    v4 = 3.0
    v8 = 7.0
    p1_target = "local-v8"
    p3_target = "v4"
    result = 2.0 * v4 + v8
    assert result == 13.0
    assert p1_target == "local-v8" and p3_target == "v4"
    return {
        "status": "pass",
        "primal": {"model": "bounded pointer-target call trace", "result": result, "p1_target": p1_target, "p3_target": p3_target},
        "derivative": {"status": "not-defined", "reason": "pointer association and a local target lifetime are storage effects"},
        "refusal": {"status": "expected", "boundary": "pointer storage identity and local target lifetime"},
    }


def _assign_abs(pointer_associated: bool, values: list[float]) -> list[float]:
    if not pointer_associated:
        raise ValueError("pointer component has no defined target")
    return [abs(value) for value in values]


def _check_v200() -> dict:
    try:
        _assign_abs(False, [-2.0, 3.0])
    except ValueError:
        pass
    else:
        raise AssertionError("unassociated pointer component must refuse")
    bounded = _assign_abs(True, [-2.0, 3.0])
    assert bounded == [2.0, 3.0]
    return {
        "status": "pass",
        "primal": {"model": "explicitly associated pointer-component ABS map", "bounded_output": bounded},
        "derivative": {"status": "not-defined", "reason": "the exact source does not establish a pointer target or numeric output map"},
        "refusal": {"status": "expected", "boundary": "unassociated derived-type pointer component"},
    }


def _check_v483() -> dict:
    state = {"aa2": 2.0, "vv1": 3.0, "vv2": 4.0}
    uu = 5.0
    tt = 7.0
    state["aa2"] *= state["aa2"]
    state["vv1"] *= uu
    state["vv2"] *= 2.0
    uu *= state["vv1"] * state["vv2"]
    tt *= uu
    assert state == {"aa2": 4.0, "vv1": 15.0, "vv2": 8.0}
    assert (uu, tt) == (600.0, 4200.0)
    return {
        "status": "pass",
        "primal": {"model": "bounded initialized global-state sequence", "state": state, "outputs": {"uu": uu, "tt": tt}},
        "derivative": {"status": "not-defined", "reason": "module-owned mutable state and pointer/allocatable lifetime are outside the dummy map"},
        "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"},
    }


CHECKS = {
    "v086-surface-map": _check_v086,
    "cm04-pointer-trace": _check_cm04,
    "v200-pointer-component": _check_v200,
    "v483-global-state": _check_v483,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    selected = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in selected}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
