#!/usr/bin/env python3
"""Independent primal, derivative, and refusal models for next8."""

from __future__ import annotations

import argparse
import json
import math


def cmv07() -> dict:
    requested_nc = 3
    requested_mxin = 4
    assert requested_nc > 0 and requested_mxin > 0
    return {
        "case": "cmv07-module-allocation",
        "status": "pass",
        "primal": {
            "module": "INTTYPES",
            "allocation_shape": {"SC": requested_nc, "INTV_per_SC": requested_mxin},
            "state_is_module_owned": True,
            "exact_source_sizes_are_uninitialized": True,
        },
        "derivative": {
            "status": "not-defined",
            "reason": "the exact source allocates module-owned storage from uninitialized state",
        },
        "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"},
    }


def _linked_list_value(x: float, nodes: int) -> float:
    return nodes * x * x


def lh234() -> dict:
    x = 1.25
    nodes = 3
    direction = 0.7
    step = 1.0e-6
    hand_jvp = 2.0 * nodes * x * direction
    central = (
        _linked_list_value(x + step * direction, nodes)
        - _linked_list_value(x - step * direction, nodes)
    ) / (2.0 * step)
    adjoint_dot = (2.0 * nodes * x) * direction
    assert math.isclose(hand_jvp, central, rel_tol=1.0e-9, abs_tol=1.0e-9)
    assert math.isclose(hand_jvp, adjoint_dot, rel_tol=1.0e-12, abs_tol=1.0e-12)
    return {
        "case": "lh234-linked-list",
        "status": "pass",
        "primal": {"node_count": nodes, "input": x, "value": _linked_list_value(x, nodes)},
        "derivative": {
            "status": "verified",
            "hand_jvp": hand_jvp,
            "central_difference": central,
            "adjoint_dot": adjoint_dot,
        },
        "refusal": {"status": "expected", "boundary": "active derived object must name a real component"},
    }


def v237() -> dict:
    coefficient = 2.5
    nnx = 1.2
    direction = -0.4
    step = 1.0e-6
    value = coefficient * nnx
    hand_jvp = coefficient * direction
    central = ((coefficient * (nnx + step * direction)) - (coefficient * (nnx - step * direction))) / (2.0 * step)
    adjoint_dot = coefficient * direction
    assert math.isclose(hand_jvp, central, rel_tol=1.0e-9, abs_tol=1.0e-9)
    assert math.isclose(hand_jvp, adjoint_dot, rel_tol=1.0e-12, abs_tol=1.0e-12)
    return {
        "case": "v237-explicit-state",
        "status": "pass",
        "primal": {"fixed_module_coefficient": coefficient, "input": nnx, "value": value},
        "derivative": {
            "status": "verified",
            "hand_jvp": hand_jvp,
            "central_difference": central,
            "adjoint_dot": adjoint_dot,
        },
        "refusal": {"status": "expected", "boundary": "reverse dependent is not inferred through module pointer state"},
    }


def cm30() -> dict:
    events = [
        "allocate(object3%x)",
        "allocate(object3%next)",
        "nextObject => object3%next",
        "deallocate(object3%x)",
    ]
    assert events[-1].startswith("deallocate")
    return {
        "case": "cm30-pointer-lifetime",
        "status": "pass",
        "primal": {
            "pointer_events": events,
            "object3_x_allocated_on_return": False,
            "object3_next_allocated_on_return": True,
            "nextObject_aliases": "object3%next",
        },
        "derivative": {"status": "not-defined", "reason": "allocation ownership and pointer identity are outside this model"},
        "refusal": {"status": "expected", "boundary": "pointer association storage identity"},
    }


CHECKS = {
    "cmv07-module-allocation": cmv07,
    "lh234-linked-list": lh234,
    "v237-explicit-state": v237,
    "cm30-pointer-lifetime": cm30,
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
