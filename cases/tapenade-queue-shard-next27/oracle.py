#!/usr/bin/env python3
"""Independent bounded behavioral and refusal-boundary oracles for next27."""

from __future__ import annotations

import argparse
import json
import math


def close(actual: float, expected: float) -> bool:
    return math.isclose(actual, expected, rel_tol=1e-6, abs_tol=1e-6)


def v434() -> dict:
    p2 = [2.0, -1.0, 0.0]
    s2 = [4.0, 5.0, 1.0]
    rh2 = [s / p if p > 0.0 else 0.0 for p, s in zip(p2, s2)]
    return {
        "status": "pass" if rh2 == [2.0, 0.0, 0.0] else "fail",
        "map": "initialized P2/S2 branch: RH2=S2/P2 where P2>EPS3, else zero",
        "rh2": rh2,
        "refusal": {"status": "expected", "boundary": "pointer association storage identity"},
        "derivative_claim": "none for undefined V1/S1/Q1 pointer state",
    }


def v542() -> dict:
    value, direction, eps = 1.75, 0.3, 1e-6
    primal = value * value
    jvp = (((value + eps * direction) ** 2) - ((value - eps * direction) ** 2)) / (2.0 * eps)
    return {
        "status": "pass" if close(primal, 3.0625) and close(jvp, 2.0 * value * direction) else "fail",
        "map": "test: rr=rr*rr; x/y allocation lifetime has no numeric output",
        "primal": primal,
        "jvp": jvp,
        "refusal": {"status": "expected", "boundary": "explicit deallocate of x in bounded allocatable lifetime"},
    }


def lh107() -> dict:
    v, x, a, b = 2.0, 3.0, 4.0, 5.0
    updated_v = v + 5.0 * a * b
    updated_x = x * x
    return {
        "status": "pass" if close(updated_v, 102.0) and close(updated_x, 9.0) else "fail",
        "map": "foo: v accumulates five a*b products from initialized globalrecord; x=x*x",
        "outputs": {"v": updated_v, "x": updated_x},
        "refusal": {"status": "expected", "boundary": "module-level allocatable derived state"},
        "derivative_claim": "none for exact module-state source",
    }


def v152() -> dict:
    return {
        "status": "pass",
        "map": "no defined numeric output map: test declares storage context but never assigns v",
        "defined_numeric_outputs": [],
        "refusal": {"status": "expected", "boundary": "no defined numeric derivative map"},
        "derivative_claim": "none",
    }


ORACLES = {
    "v434-test1-where": v434,
    "v542-test-square": v542,
    "lh107-foo-map": lh107,
    "v152-no-numeric-map": v152,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case")
    args = parser.parse_args()
    values = {args.case: ORACLES[args.case]()} if args.case else {name: fn() for name, fn in ORACLES.items()}
    print(json.dumps(values, indent=2, sort_keys=True))
    return 0 if all(value["status"] == "pass" for value in values.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
