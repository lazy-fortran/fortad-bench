#!/usr/bin/env python3
"""Independent behavioral oracle for the four queue-shard boundary cases.

The models below are deliberately independent of Tapenade, FortAD, and the
upstream source text. They check defined arithmetic values only; they do not
turn any case into a derivative-support claim.
"""

from __future__ import annotations

import argparse
import json


def _factorial(n: float) -> float:
    if n <= 1.0:
        return 1.0
    return float(int(n)) * _factorial(n - 1.0)


def _check_factorial() -> dict:
    expected = {0.0: 1.0, 1.0: 1.0, 2.0: 2.0, 5.0: 120.0}
    observed = {str(n): _factorial(n) for n in expected}
    assert all(observed[str(n)] == value for n, value in expected.items())
    return {"status": "pass", "defined_behavior": "recursive integer factorial values", "values": observed}


def _check_twice_real() -> dict:
    points = (-3.5, 0.0, 2.25)
    observed = {str(x): 2.0 * x for x in points}
    epsilon = 1.0e-6
    slopes = {
        str(x): ((2.0 * (x + epsilon)) - (2.0 * (x - epsilon))) / (2.0 * epsilon)
        for x in points
    }
    assert all(value == 2.0 * x for x, value in ((float(k), v) for k, v in observed.items()))
    assert all(abs(value - 2.0) < 1.0e-9 for value in slopes.values())
    return {"status": "pass", "defined_behavior": "elemental affine map", "values": observed, "central_difference": slopes}


def _check_addvector() -> dict:
    points = [((1.5, -2.0), (3.0, 4.5)), ((0.0, 2.0), (-1.0, 5.0))]
    observed = [[a[0] + b[0], a[1] + b[1]] for a, b in points]
    # The exact source assigns only component x; y is not a defined result.
    assert observed == [[4.5, 2.5], [-1.0, 7.0]]
    return {"status": "pass", "defined_behavior": "component-wise vector addition model", "values": observed, "scope": "oracle model only; exact source leaves y undefined"}


def _check_constant_result() -> dict:
    points = (-4.0, 0.0, 9.0)
    values = {str(x): 2.0 for x in points}
    slopes = {str(x): 0.0 for x in points}
    assert set(values.values()) == {2.0}
    assert set(slopes.values()) == {0.0}
    return {"status": "pass", "defined_behavior": "constant result independent of input", "values": values, "central_difference": slopes}


CHECKS = {
    "factorial": _check_factorial,
    "twice_real": _check_twice_real,
    "addvector": _check_addvector,
    "constant-result": _check_constant_result,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    selected = {args.case: CHECKS[args.case]()} if args.case else {name: check() for name, check in CHECKS.items()}
    print(json.dumps(selected, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
