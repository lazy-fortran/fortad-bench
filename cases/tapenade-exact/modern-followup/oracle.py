#!/usr/bin/env python3
"""Independent primal/refusal models for the modern follow-up shard."""

from __future__ import annotations

import argparse
import json


def _check_v030() -> dict:
    left = (1.5, 2.5)
    right = (3.0, 4.0)
    result = (left[0] + right[0], left[1] + right[1])
    assert result == (4.5, 6.5)
    return {
        "case": "v030-interval-addition",
        "status": "pass",
        "primal": {"model": "closed interval endpoint addition", "left": left, "right": right, "result": result},
        "derivative": {"status": "not-defined", "reason": "FortAD does not represent active derived-type components"},
        "refusal": {"status": "expected", "boundary": "active derived object must name a real component"},
    }


def _pointer_allocation_model(case: str) -> dict:
    x = [1.0, 2.0, 3.0, 4.0]
    y = [2.0, 3.0, 4.0, 5.0, 6.0]
    x[2] = x[3] * y[1]
    z = [x[2] * index for index in range(7)]
    lpp = [x[index] * index * y[index + 1] for index in range(4)]
    for index in range(4):
        y[index] = y[index + 1] - lpp[index]
    pp = [index * y[index // 2] for index in range(10)]
    pp[6] *= z[0]
    x[3] = pp[3] * pp[2]
    x[0] *= x[3]
    result = 1.0
    for index in range(4):
        result *= pp[index] * z[5 - index]
    z[:] = [0.0] * 7
    x[2] = result
    assert x == [96.0, 2.0, 0.0, 96.0]
    assert y == [3.0, -4.0, -115.0, -66.0, 6.0]
    assert result == 0.0
    return {
        "case": case,
        "status": "pass",
        "primal": {"model": "pointer allocation, cross-call mutation, and deallocation", "x": x, "y": y, "pointer_deallocated": True},
        "derivative": {"status": "not-defined", "reason": "pointer association storage identity is not represented"},
        "refusal": {"status": "expected", "boundary": "pointer association storage identity"},
    }


def _check_mvo34() -> dict:
    class State:
        def __init__(self) -> None:
            self.value = 5.0
            self.target = None

    def fun2(state: State, values: list[float]) -> list[float]:
        output = [state.value * value for value in values]
        state.value += values[1]
        return output

    def fun3(state: State, values: list[float]) -> list[float]:
        output = [state.value * value for value in values]
        state.value += values[0]
        return output

    state = State()
    values = [1.0, 2.0]
    state.target = fun2
    first = state.target(state, values)
    state.target = fun3
    second = state.target(state, values)
    assert first == [5.0, 10.0] and second == [7.0, 14.0] and state.value == 8.0
    return {
        "case": "mvo34-type-set-func",
        "status": "pass",
        "primal": {"model": "polymorphic procedure-pointer dispatch", "first": first, "second": second, "final_value": state.value},
        "derivative": {"status": "not-defined", "reason": "dynamic procedure-pointer target and polymorphic dispatch are not represented"},
        "refusal": {"status": "expected", "boundary": "polymorphic procedure-pointer interface"},
    }


CHECKS = {
    "v030-interval-addition": _check_v030,
    "v534-testallocs": lambda: _pointer_allocation_model("v534-testallocs"),
    "mvo34-type-set-func": _check_mvo34,
    "v535-testallocs": lambda: _pointer_allocation_model("v535-testallocs"),
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
