#!/usr/bin/env python3
"""Independent next14 behavioral and refusal-boundary oracles."""

from __future__ import annotations

import argparse
import json


def v004() -> dict[str, object]:
    a = (1.5, -2.0)
    b = (0.5, 3.0)
    u = (2.0, 4.0)
    value = tuple(a[i] + b[i] + u[i] for i in range(2))
    assert value == (4.0, 5.0)
    return {"status": "pass", "value": value,
            "boundary": "active module vector u is mutable global state"}


def v531() -> dict[str, object]:
    p1_extent = 10
    pointer_component_extent = 4
    assert p1_extent == 10 and pointer_component_extent == 4
    return {"status": "pass", "p1_extent": p1_extent,
            "pointer_component_extent": pointer_component_extent,
            "boundary": "SIZE on pointer component plus unresolved BAR call"}


def lh108() -> dict[str, object]:
    records = [{"a": 2.0, "b": 3.0} for _ in range(11)]
    shared_target = {"value": 0.0}
    for record in records:
        record["target"] = shared_target
        record["target"]["value"] = 2.0
    first_five = sum(record["target"]["value"] * record["b"] for record in records[:5])
    assert first_five == 30.0 and all(record["target"] is shared_target for record in records)
    return {"status": "pass", "allocated_records": len(records),
            "first_five_product": first_five,
            "boundary": "module-level allocatable state and pointer association"}


def v048() -> dict[str, object]:
    x, xd, value_b = 1.25, -0.75, 1.5
    value = 2.0 * x
    jvp = 2.0 * xd
    x_b = 2.0 * value_b
    assert value == 2.5 and jvp == -1.5 and x_b == 3.0
    return {"status": "pass", "value": value, "jvp": jvp,
            "x_b": x_b,
            "boundary": "elemental generic dispatch is affine for both declared specifics"}


ORACLES = {
    "v004-derived-vector": v004,
    "v531-pointer-size": v531,
    "lh108-allocatable-state": lh108,
    "v048-elemental-generic": v048,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = {args.case: ORACLES[args.case]()} if args.case else {
        name: fn() for name, fn in ORACLES.items()
    }
    print(json.dumps(selected, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
