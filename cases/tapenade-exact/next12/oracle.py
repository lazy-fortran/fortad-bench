"""Independent next12 primal oracles; no derivative-support claim."""

from __future__ import annotations

import argparse
import json
import math


def v058() -> dict:
    x = [1.0, 2.0, 0.0, 4.0]
    first = [1.0 / value if value != 0.0 else None for value in x]
    second = [1.0 / value if value != 0.0 else value for value in x]
    third = [1.0 / value if value in (1.0, 2.0, 3.0) else 0.0 for value in x]
    assert first == [1.0, 0.5, None, 0.25]
    assert second == [1.0, 0.5, 0.0, 0.25]
    assert third == [1.0, 0.5, 0.0, 0.0]
    value = 1.7
    direction = -0.3
    step = 1.0e-6
    central = ((1.0 / (value + step * direction)) -
               (1.0 / (value - step * direction))) / (2.0 * step)
    jvp = -direction / value**2
    assert math.isclose(central, jvp, rel_tol=1.0e-8, abs_tol=1.0e-8)
    return {"case": "v058-where-reciprocal", "status": "pass",
            "primal": {"where_nonzero": first, "where_else": second,
                       "where_multi_branch": third},
            "derivative": {"status": "model-only", "reciprocal_jvp": jvp},
            "refusal": {"status": "expected", "boundary": "elemental-expansion generic call"}}


def v176() -> dict:
    real_pair = [1.25, -2.5]
    double_pair = [3.0, 7.0]
    def swap(pair: list[float]) -> list[float]:
        return [pair[1], pair[0]]
    after_sub1 = (swap(double_pair), swap(real_pair))
    after_head = (swap(after_sub1[0]), swap(after_sub1[1]))
    assert after_sub1 == ([7.0, 3.0], [-2.5, 1.25])
    assert after_head == (double_pair, real_pair)
    return {"case": "v176-generic-swap", "status": "pass",
            "primal": {"after_sub1": after_sub1, "after_head": after_head},
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "expected", "boundary": "COMMON/global mutable state"}}


def cmv04() -> dict:
    v2, v3 = 2.5, -4.0
    r = v3 * v2
    assert r == -10.0
    return {"case": "cmv04-pointer-target", "status": "pass",
            "primal": {"target": "v3", "r": r},
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "expected", "boundary": "pointer association storage identity"}}


def v175() -> dict:
    double_pair = [3.0, 7.0]
    real_pair = [2.0, -5.0]
    swapped = ([double_pair[1], double_pair[0]], [real_pair[1], real_pair[0]])
    assert swapped == ([7.0, 3.0], [-5.0, 2.0])
    return {"case": "v175-generic-swap", "status": "pass",
            "primal": {"double_pair": swapped[0], "real_pair": swapped[1]},
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "expected", "boundary": "COMMON/global mutable state"}}


CHECKS = {"v058-where-reciprocal": v058, "v176-generic-swap": v176,
          "cmv04-pointer-target": cmv04, "v175-generic-swap": v175}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    names = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in names}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
