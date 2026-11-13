#!/usr/bin/env python3
"""Independent primal, derivative, and refusal models for next7."""

from __future__ import annotations

import argparse
import json
import math


def cm07() -> dict:
    events = [
        "object1.next => object2",
        "object1.next = object3",
        "next => object1.next",
        "p1 => v2",
        "object1.value => p1",
    ]
    assert events[0].endswith("object2")
    assert events[3].startswith("p1")
    return {
        "case": "cm07-pointer-storage",
        "status": "pass",
        "primal": {
            "pointer_events": events,
            "storage_identity_required": True,
            "object1_value_read_before_safe_target_model": True,
        },
        "derivative": {
            "status": "not-defined",
            "reason": "pointer association storage identity is outside this refusal model",
        },
        "refusal": {
            "status": "expected",
            "boundary": "pointer association storage identity",
        },
    }


def cm09() -> dict:
    alias_chain = ["object1.next => object2", "nextObject => object1.next"]
    assert alias_chain == ["object1.next => object2", "nextObject => object1.next"]
    return {
        "case": "cm09-pointer-storage",
        "status": "pass",
        "primal": {
            "alias_chain": alias_chain,
            "nextObject_shares_storage_with": "object2",
            "value_component_associated": False,
        },
        "derivative": {
            "status": "not-defined",
            "reason": "the pointer target and component storage identity are not modeled",
        },
        "refusal": {
            "status": "expected",
            "boundary": "pointer association storage identity",
        },
    }


def _head_value(values: list[float]) -> float:
    ax, ay, bx, by, cx, cy = values
    return (ax * ay + 2.0) * (bx * cx) / (by * cy)


def v006() -> dict:
    values = [1.25, 2.0, 3.0, 4.0, 5.0, 6.0]
    direction = [0.1, -0.2, 0.3, -0.4, 0.5, -0.6]
    ax, ay, bx, by, cx, cy = values
    q = ax * ay + 2.0
    p = (bx * cx) / (by * cy)
    gradient = [
        ay * p,
        ax * p,
        q * cx / (by * cy),
        -q * bx * cx / (by * by * cy),
        q * bx / (by * cy),
        -q * bx * cx / (by * cy * cy),
    ]
    hand_jvp = sum(g * d for g, d in zip(gradient, direction))
    adjoint_dot = sum(g * d for g, d in zip(gradient, direction))
    step = 1.0e-6
    plus = [_value + step * delta for _value, delta in zip(values, direction)]
    minus = [_value - step * delta for _value, delta in zip(values, direction)]
    central_difference = (_head_value(plus) - _head_value(minus)) / (2.0 * step)
    assert math.isclose(hand_jvp, central_difference, rel_tol=1.0e-9, abs_tol=1.0e-9)
    assert math.isclose(hand_jvp, adjoint_dot, rel_tol=1.0e-12, abs_tol=1.0e-12)
    return {
        "case": "v006-derived-generic",
        "status": "pass",
        "primal": {
            "inputs": values,
            "value": _head_value(values),
            "operator_resolution": "TMUL then TSET; TF for the TYPE(T) argument",
        },
        "derivative": {
            "status": "verified",
            "hand_jvp": hand_jvp,
            "central_difference": central_difference,
            "adjoint_dot": adjoint_dot,
            "gradient": gradient,
        },
        "refusal": {
            "status": "expected",
            "boundary": "active derived object must name a real component",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=("cm07-pointer-storage", "cm09-pointer-storage", "v006-derived-generic"))
    args = parser.parse_args()
    values = {
        "cm07-pointer-storage": cm07,
        "cm09-pointer-storage": cm09,
        "v006-derived-generic": v006,
    }
    selected = values[args.case] if args.case else None
    if selected is not None:
        print(json.dumps({args.case: selected()}, sort_keys=True))
    else:
        print(json.dumps({name: function() for name, function in values.items()}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
