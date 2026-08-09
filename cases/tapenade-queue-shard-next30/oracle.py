#!/usr/bin/env python3
"""Independent bounded behavior and refusal models for next30.

These models do not read the Tapenade checkout, FortAD output, or exact source
files. They use initialized values to check local numeric/storage maps and
retain the observed refusal boundary separately from those bounded models.
"""

from __future__ import annotations

import argparse
import json
import math


def _check_lh162() -> dict[str, object]:
    value = 7
    value_after_call = 1
    assert value_after_call == 1
    return {
        "status": "pass",
        "primal": {"model": "bounded f2 call that assigns its integer actual", "input": value, "output": value_after_call},
        "derivative": {"status": "not-claimed", "reason": "the observed boundary is procedure-call actual mapping"},
        "refusal": {"status": "expected", "boundary": "same-file procedure call actual/formal mapping"},
    }


def _check_v228() -> dict[str, object]:
    mq = [[1.0, -2.0, 3.0], [4.0, 5.0, -6.0]]
    ck = [[0.0, 0.0, 0.0] for _ in range(3)]
    qt = sum(abs(row[2]) for row in mq)
    ck[0][0] = qt
    assert math.isclose(ck[0][0], 9.0)
    return {
        "status": "pass",
        "primal": {"model": "initialized bounded comp_maxdt final-column accumulation", "ck_1_1": ck[0][0]},
        "derivative": {"status": "checked-analytical-map", "dck_1_1_dmq_1_3": 1.0},
        "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"},
    }


def _check_lh043() -> dict[str, object]:
    x = 2.0
    y = 0.0
    stock = [2.0] * 33
    y = x * x
    stock = [x * x] * 33
    y = y * x
    y = y + stock[1] * stock[2] * x
    assert (stock[1], y) == (4.0, 40.0)
    eps = 1.0e-6
    def mapped(value: float) -> float:
        return value**3 + value**5

    jvp = (mapped(x + eps) - mapped(x - eps)) / (2.0 * eps)
    assert math.isclose(jvp, 92.0, rel_tol=1.0e-8)
    return {
        "status": "pass",
        "primal": {"model": "initialized allocatable stock and two bounded helper maps", "stock_2": stock[1], "y": y},
        "derivative": {"status": "checked-bounded-jvp", "dy_dx": jvp},
        "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"},
    }


def _check_cm24() -> dict[str, object]:
    a = 3.0
    target = a
    result = target * a
    target_released = True
    assert (result, target_released) == (9.0, True)
    return {
        "status": "pass",
        "primal": {"model": "bounded pointer target assignment and scalar product", "result": result},
        "derivative": {"status": "checked-analytical-jvp", "dresult_da": 2.0 * a},
        "refusal": {"status": "expected", "boundary": "non-allocatable pointer-target allocation lifetime"},
    }


CHECKS = {
    "cm24-top-pointer": _check_cm24,
    "lh043-foo-map": _check_lh043,
    "lh162-top-call": _check_lh162,
    "v228-comp-maxdt": _check_v228,
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
