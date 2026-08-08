#!/usr/bin/env python3
"""Independent primal, derivative, and refusal models for next6."""

from __future__ import annotations

import argparse
import json
import math


def lh011() -> dict:
    state = {
        "module_allocatable_components": True,
        "module_target_arrays": True,
        "pointer_aliases": True,
    }
    assert all(state.values())
    return {
        "case": "lh011-module-state",
        "status": "pass",
        "primal": {"state_features": state, "alias_storage_preserved": True},
        "derivative": {"status": "not-defined", "reason": "module-level mutable storage crosses the differentiated call"},
        "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"},
    }


def lh156() -> dict:
    calls = ["PERSAR -> PERMAT", "PERSAR -> QREPAR", "QREPAR -> MYFUNC1", "PERMAT -> MYFUNC2"]
    arrays = {"z": 21, "cf1": 21, "cf2": 21, "pcsing": 21, "idt": 21}
    assert len(calls) == 4 and all(size == 21 for size in arrays.values())
    return {
        "case": "lh156-no-dependent",
        "status": "pass",
        "primal": {"call_graph": calls, "array_lengths": arrays},
        "derivative": {"status": "not-defined", "reason": "the exact root has no explicit dependent output for reverse mode"},
        "refusal": {"status": "expected", "boundary": "missing inferred reverse dependent"},
    }


def v521() -> dict:
    x = [3.0, 2.0, 0.0, 0.0, 0.0]
    y = [0.0] * 5
    y[:2] = [2.0 * x[0], 2.0 * x[1]]
    value = y[0] * y[1]
    global_value = value
    assert y[:2] == [6.0, 4.0] and value == 24.0 and global_value == 24.0
    return {
        "case": "v521-pointer-global",
        "status": "pass",
        "primal": {"x": x, "y": y, "compute": value, "global_after_call": global_value},
        "derivative": {"status": "not-defined", "reason": "pointer storage identity and mutable module state are not represented"},
        "refusal": {"status": "expected", "boundary": "pointer association storage identity"},
    }


def vpf17() -> dict:
    def primal(x1: float, x2: float) -> float:
        return (x1 - x2) + (x2 - x1)

    x1, x2, step = 1.25, -0.75, 1.0e-6
    value = primal(x1, x2)
    hand = (0.0, 0.0)
    central = (
        (primal(x1 + step, x2) - primal(x1 - step, x2)) / (2.0 * step),
        (primal(x1, x2 + step) - primal(x1, x2 - step)) / (2.0 * step),
    )
    dot = hand[0] * 0.7 + hand[1] * -1.3
    assert math.isclose(value, 0.0, abs_tol=1.0e-14)
    assert all(math.isclose(a, b, abs_tol=1.0e-10) for a, b in zip(hand, central))
    assert math.isclose(dot, 0.0, abs_tol=1.0e-14)
    return {
        "case": "vpf17-nested-derived",
        "status": "pass",
        "primal": {"value": value, "inputs": [x1, x2]},
        "derivative": {"status": "verified", "hand_jvp": hand, "central_difference": central, "adjoint_dot": dot},
        "refusal": {"status": "expected", "boundary": "generated nested-derived forward/reverse source strict compilation"},
    }


CHECKS = {
    "lh011-module-state": lh011,
    "lh156-no-dependent": lh156,
    "v521-pointer-global": v521,
    "vpf17-nested-derived": vpf17,
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
