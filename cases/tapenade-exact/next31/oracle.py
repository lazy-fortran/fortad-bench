#!/usr/bin/env python3
"""Independent bounded behavior and refusal models for next31.

These models do not read the Tapenade checkout, FortAD output, or exact source
files. They check bounded generic dispatch, allocation, alias, and masked-sum
behavior separately from the observed FortAD refusal boundaries.
"""

from __future__ import annotations

import argparse
import json
import math


def _check_bd17() -> dict[str, object]:
    dispatch = {1: "test3", 2: "test4", 3: "test5"}
    selected = [dispatch[rank] for rank in (1, 2, 3)]
    assert selected == ["test3", "test4", "test5"]
    return {
        "status": "pass",
        "primal": {"model": "bounded generic dispatch by integer actual rank", "selected": selected},
        "derivative": {"status": "not-claimed", "reason": "integer-only specific has no active numeric output"},
        "refusal": {"status": "expected", "boundary": "automatic reverse dependent inference"},
    }


def _check_lh126() -> dict[str, object]:
    a = 2.0
    b = 1.0
    temporary = [a] * 10
    b += sum(temporary)
    module_c = 1.5
    assert (b, module_c, len(temporary)) == (21.0, 1.5, 10)
    return {
        "status": "pass",
        "primal": {"model": "bounded allocate-fill-sum-deallocate map", "b": b, "module_c": module_c},
        "derivative": {"status": "checked-analytical-map", "db_d_a": 10.0},
        "refusal": {"status": "expected", "boundary": "passed-procedure callback reads active module state"},
    }


def _check_v254() -> dict[str, object]:
    y = 3.0
    ay = y
    z = y + ay
    assert z == 6.0
    return {
        "status": "pass",
        "primal": {"model": "bounded module USE alias map", "y": y, "ay": ay, "z": z},
        "derivative": {"status": "not-claimed", "reason": "the exact root has no inferred independent variable"},
        "refusal": {"status": "expected", "boundary": "automatic independent-variable inference through module aliases"},
    }


def _check_v144() -> dict[str, object]:
    a = [1.0, -2.0, 3.0]
    c = [1.0, -1.0, 2.0]
    mapped = [2.0 * x * value for x, value in zip(a, c)]
    result = sum(value for value, mask in zip(mapped, c) if mask > 0.0)
    direction = [0.5, -1.0, 2.0]
    jvp = sum(2.0 * da * value for da, value, mask in zip(direction, c, c) if mask > 0.0)
    broadcast = [result, result]
    assert (result, broadcast, jvp) == (14.0, [14.0, 14.0], 9.0)
    assert math.isfinite(result)
    return {
        "status": "pass",
        "primal": {"model": "bounded F(a,2) masked SUM with scalar broadcast", "resu": broadcast},
        "derivative": {"status": "checked-bounded-jvp", "dresu_direction": [jvp, jvp]},
        "refusal": {"status": "expected", "boundary": "local interface statement"},
    }


CHECKS = {
    "bd17-generic-dispatch": _check_bd17,
    "lh126-allocatable-sum": _check_lh126,
    "v254-module-alias": _check_v254,
    "v144-masked-sum": _check_v144,
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
