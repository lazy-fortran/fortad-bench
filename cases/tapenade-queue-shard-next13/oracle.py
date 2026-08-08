"""Independent next13 primal and refusal-boundary oracles."""

from __future__ import annotations

import argparse
import json


def v364() -> dict[str, object]:
    nodes = [
        {"value": 1.25, "name": "one", "next": 1},
        {"value": 3.5, "name": "three", "next": 2},
        {"value": 8.0, "name": "eight", "next": None},
    ]

    def find(name: str) -> float | None:
        index = 0
        while index is not None:
            node = nodes[index]
            if name == node["name"]:
                return node["value"]
            index = node["next"]
        return None

    assert find("three") == 3.5
    assert find("missing") is None
    return {"status": "pass", "found": 3.5, "missing": None,
            "boundary": "pointer-association storage identity"}


def lh112() -> dict[str, object]:
    x0, y0, n = 2.0, 1.5, 90
    seed = x0 * x0
    x_after = seed
    fff1 = 2.0 * seed
    fff2 = 2.0 * seed * seed
    x_after_pointer_write = 3.0 * x_after
    y_after_active_call = y0 + x_after + n * fff1 + n * fff2
    assert (x_after_pointer_write, y_after_active_call) == (12.0, 3605.5)
    return {"status": "pass", "active_x": x_after_pointer_write,
            "active_y": y_after_active_call,
            "boundary": "derived-array TARGET alias storage identity",
            "scope": "defined active-prefix behavior only; passive uninitialized tail is excluded"}


def lh051() -> dict[str, object]:
    x, y = 1.5, 0.7
    x_after = 3.1 * x * x
    v_after = 4.2 * y * y
    sub = v_after * v_after
    z = x_after * sub
    assert abs(z - 29.5416639) < 1.0e-12
    return {"status": "pass", "x_after": x_after, "sub": sub, "z": z,
            "boundary": "TARGET/P pointer alias storage identity"}


def cm25() -> dict[str, object]:
    a = -2.5
    allocated = True
    r = a * a
    allocated = False
    assert r == 6.25 and not allocated
    return {"status": "pass", "a": a, "r": r, "allocated_after": allocated,
            "boundary": "derived-component pointer allocation"}


ORACLES = {"v364-linked-list": v364, "lh112-active-prefix": lh112,
           "lh051-target-alias": lh051, "cm25-component-allocation": cm25}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = {args.case: ORACLES[args.case]()} if args.case else {name: fn() for name, fn in ORACLES.items()}
    print(json.dumps(selected, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
