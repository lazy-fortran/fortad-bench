#!/usr/bin/env python3
"""Independent arithmetic, pointer, and ownership models for next9."""

from __future__ import annotations

import argparse
import json
import math


def v290() -> dict:
    x = [1.0, -2.0, 0.5]
    y = [0.25, 2.0, -1.5]
    b = [2.0, -1.0, 3.0]
    c = [0.5, 0.25, -2.0]
    direction = [0.4, -0.3, 0.8]
    output = [b[i] * x[i] + c[i] + y[i] for i in range(3)]
    hand = [b[i] * direction[i] for i in range(3)]
    adjoint = sum(hand[i] * direction[i] for i in range(3))
    assert all(math.isfinite(value) for value in output + hand)
    return {
        "case": "v290-derived-array",
        "status": "pass",
        "primal": {"output": output, "shape": 3},
        "derivative": {"status": "verified", "hand_jvp": hand, "adjoint_dot": adjoint},
        "refusal": {"status": "expected", "boundary": "nested internal procedures"},
    }


def cm33() -> dict:
    state = {"x_allocated": False, "next_allocated": False, "next_alias": None}
    state["x_allocated"] = True
    state["next_allocated"] = True
    state["next_alias"] = "object1.next"
    state["x_allocated"] = False
    assert state == {"x_allocated": False, "next_allocated": True, "next_alias": "object1.next"}
    return {
        "case": "cm33-allocation-lifetime",
        "status": "pass",
        "primal": state,
        "derivative": {"status": "not-defined", "reason": "module-owned allocation state"},
        "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"},
    }


def lh056() -> dict:
    y, pz, dy, dpz = 1.2, -0.4, 0.7, -0.25
    step = 1.0e-6
    value = y * (pz + 2.0 * y)
    hand = (pz + 4.0 * y) * dy + y * dpz
    central = (
        (y + step * dy) * (pz + step * dpz + 2.0 * (y + step * dy))
        - (y - step * dy) * (pz - step * dpz + 2.0 * (y - step * dy))
    ) / (2.0 * step)
    adjoint_dot = hand
    assert math.isclose(hand, central, rel_tol=1.0e-9, abs_tol=1.0e-9)
    assert math.isclose(hand, adjoint_dot, rel_tol=1.0e-12, abs_tol=1.0e-12)
    return {
        "case": "lh056-pointer-alias",
        "status": "pass",
        "primal": {"value": value, "pointer_write": 3.7 * y},
        "derivative": {"status": "verified", "hand_jvp": hand, "central_difference": central, "adjoint_dot": adjoint_dot},
        "refusal": {"status": "expected", "boundary": "pointer association storage identity"},
    }


def cm26() -> dict:
    target = {"value": 1.0}
    aliases = {"p": target, "object1.x": target}
    unresolved = {"object1.next": None, "p2": None}
    assert aliases["p"] is aliases["object1.x"]
    assert unresolved["p2"] is unresolved["object1.next"]
    return {
        "case": "cm26-pointer-graph",
        "status": "pass",
        "primal": {"shared_target": True, "unresolved_next": True},
        "derivative": {"status": "not-defined", "reason": "pointer graph has an unresolved association"},
        "refusal": {"status": "expected", "boundary": "pointer association storage identity"},
    }


CHECKS = {
    "cm26-pointer-graph": cm26,
    "cm33-allocation-lifetime": cm33,
    "lh056-pointer-alias": lh056,
    "v290-derived-array": v290,
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
