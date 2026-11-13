#!/usr/bin/env python3
"""Independent primal and refusal-boundary models for the next3 shard."""

from __future__ import annotations

import argparse
import json
import math


def _mvo32() -> dict:
    def dispatch(x: float) -> float:
        return x * x if x > 0.0 else x

    positive = dispatch(2.5)
    negative = dispatch(-2.5)
    assert positive == 6.25 and negative == -2.5
    return {
        "case": "mvo32-callback",
        "status": "pass",
        "primal": {"model": "conditional procedure-pointer callback", "positive": positive, "negative": negative},
        "derivative": {"status": "not-defined", "reason": "conditional procedure-pointer target flow is unresolved"},
        "refusal": {"status": "expected", "boundary": "indirect procedure-pointer callback call"},
    }


def _mvo31() -> dict:
    receiver_a = 3.0
    x = 2.5
    value = receiver_a * x
    assert value == 7.5
    return {
        "case": "mvo31-type-bound",
        "status": "pass",
        "primal": {"model": "polymorphic type-bound procedure", "receiver_a": receiver_a, "x": x, "value": value},
        "derivative": {"status": "not-defined", "reason": "active polymorphic receiver dynamic type is not represented"},
        "refusal": {"status": "expected", "boundary": "active polymorphic type-bound receiver"},
    }


def _lh109() -> dict:
    def evaluate(x: float) -> tuple[float, float]:
        rr = 12.5
        field = [0.0] * (19 * 29)
        rr = x * rr
        if x > 0.0:
            field = [math.sqrt(x)] * len(field)
        y = x * rr
        if x > 10.0:
            y += sum(field)
        return rr, y

    rr2, y2 = evaluate(2.0)
    rr11, y11 = evaluate(11.0)
    assert rr2 == 25.0 and y2 == 50.0
    assert rr11 == 137.5 and abs(y11 - (1512.5 + 551.0 * math.sqrt(11.0))) < 1.0e-12
    return {
        "case": "lh109-local-component",
        "status": "pass",
        "primal": {"model": "local derived pointer-component allocation", "x2": {"rr": rr2, "y": y2}, "x11": {"rr": rr11, "y": y11}},
        "derivative": {"status": "not-defined", "reason": "generic allocation of a derived pointer component has no derivative output"},
        "refusal": {"status": "expected", "boundary": "derived-component allocation through generic BARALLOC"},
    }


def _lh121() -> dict:
    x = 1.4
    mm1 = [0.0] * 11
    ptr = mm1
    ptr[:] = [x * x] * len(ptr)
    y = ptr[2] * ptr[4]
    same_storage = ptr is mm1
    mm1 = None
    assert same_storage and abs(y - 3.8416) < 1.0e-12 and mm1 is None
    return {
        "case": "lh121-alias-lifetime",
        "status": "pass",
        "primal": {"model": "local allocatable TARGET and pointer alias", "x": x, "y": y, "aliased_storage": same_storage},
        "derivative": {"status": "not-defined", "reason": "TARGET alias identity and deallocation lifetime are not represented"},
        "refusal": {"status": "expected", "boundary": "allocatable TARGET pointer association and deallocation"},
    }


CHECKS = {
    "lh109-local-component": _lh109,
    "mvo32-callback": _mvo32,
    "mvo31-type-bound": _mvo31,
    "lh121-alias-lifetime": _lh121,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    names = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in names}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
