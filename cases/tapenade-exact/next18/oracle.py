#!/usr/bin/env python3
"""Independent behavioral and refusal-boundary oracles for next18."""

from __future__ import annotations

import argparse
import json


def lh099() -> dict[str, object]:
    # The loop keeps its index fixed.  A bounded model makes the defined
    # transition observable without executing a potentially non-terminating
    # upstream trace.
    a = [0.0] * 100
    b = [0.0] * 100
    a[4], b[4] = 20.0, 3.0
    iterations = 0
    while abs(a[4]) > 10.0:
        a[4] = 2.0 * b[4]
        iterations += 1
        assert iterations <= 1
    assert a[4] == 6.0 and iterations == 1
    return {"status": "pass", "fixed_index": 5, "iterations": iterations, "value": a[4], "boundary": "DO WHILE control flow"}


def lh101() -> dict[str, object]:
    point = {"x": 1.5, "y": 2.5}
    triangle = {"a": dict(point), "b": dict(point), "rk": 4.0}
    common = {"p2": [{"x": 7.0, "y": 8.0}], "y": 3.0, "z": 0.0}
    triangle["a"]["x"] = point["y"]
    common["p2"][0]["x"] = 9.0
    sss1_x = common["p2"][0]["x"] + triangle["a"]["y"] * 2.0
    sss1_y = triangle["rk"] * sss1_x
    common["p2"][0]["y"] = triangle["rk"] - common["y"]
    assert triangle["a"]["x"] == 2.5
    assert sss1_x == 14.0 and sss1_y == 56.0
    assert common["p2"][0]["y"] == 1.0
    return {"status": "pass", "nested_component": triangle["a"], "common_state": common, "boundary": "invalid upstream: non-SEQUENCE derived type in COMMON and incompatible implicit SSS1 interface"}


def lh106() -> dict[str, object]:
    i1, i2, i3 = 2.0, 2.0, -4.0
    if i3 < 0.0:
        i3 = i1 - i2
    i1 = i2 - i3
    i2 = 2.3
    x1 = i1 - i3
    o3 = i3 * i2
    x2 = 5.0
    x1 = i1 * i2
    if i1 > 3.0:
        x2 = x2 + i1 - 3.0 * i2
    else:
        x2 = 12.0
        x1 = 2.0 * x1 + x2
    o1 = x1 / x2
    o2 = 35.0
    o1 = o1 * o2 * i2
    o3 = 2.0
    i1 = 99.0
    i2 = 5.0
    assert (i1, i2, i3) == (99.0, 5.0, 0.0)
    assert abs(o1 - (21.2 / 12.0) * 35.0 * 2.3) < 1.0e-12 and o2 == 35.0 and o3 == 2.0
    return {"status": "pass", "outputs": {"o1": o1, "o2": o2, "o3": o3}, "boundary": "multiple output/dependent selection for reverse mode"}


def lh108() -> dict[str, object]:
    common = {"x": [None] * 14, "y": None}
    common["x"][0] = "y*z+t depends on COMMON y"
    assert common["x"][0].startswith("y*z") and common["y"] is None
    return {"status": "pass", "common_state": common, "boundary": "COMMON storage plus undefined local index/value prevents a numeric derivative claim"}


ORACLES = {
    "lh099-do-while": lh099,
    "lh101-derived-common": lh101,
    "lh106-multiple-outputs": lh106,
    "lh108-common-undefined-storage": lh108,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = {args.case: ORACLES[args.case]()} if args.case else {name: fn() for name, fn in ORACLES.items()}
    print(json.dumps(selected, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
