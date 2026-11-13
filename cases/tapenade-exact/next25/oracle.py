#!/usr/bin/env python3
"""Independent bounded behavioral/refusal oracles for the next25 shard."""

from __future__ import annotations

import argparse
import json
import math


def close(actual: float, expected: float) -> bool:
    return math.isclose(actual, expected, rel_tol=1e-6, abs_tol=1e-6)


def v397() -> dict:
    def primal(x: float) -> float:
        return 2.0 * x

    x = 1.75
    dx = -0.4
    eps = 1e-6
    jvp = (primal(x + eps * dx) - primal(x - eps * dx)) / (2.0 * eps)
    output_bar = 1.3
    input_bar = 2.0 * output_bar
    return {
        "status": "pass" if close(primal(x), 3.5) and close(jvp, 2.0 * dx) and close(input_bar, 2.6) else "fail",
        "map": "y=2*x through the concrete i_a interface branch",
        "jvp": jvp,
        "vjp": input_bar,
    }


def vpf15() -> dict:
    def primal(x1: float, x2: float) -> float:
        return x1 - x2

    x1, x2 = 3.25, -0.75
    dx1, dx2 = -0.2, 0.6
    eps = 1e-6
    jvp = (primal(x1 + eps * dx1, x2 + eps * dx2) - primal(x1 - eps * dx1, x2 - eps * dx2)) / (2.0 * eps)
    output_bar = -1.4
    x1_bar, x2_bar = output_bar, -output_bar
    return {
        "status": "pass" if close(primal(x1, x2), 4.0) and close(jvp, dx1 - dx2) and close(x1_bar, -1.4) and close(x2_bar, 1.4) else "fail",
        "map": "y=x(1)-x(2) through overloaded some_type_difference",
        "jvp": jvp,
        "vjp": {"x1": x1_bar, "x2": x2_bar},
    }


def cm23() -> dict:
    def primal(_a1: float, _a2: float) -> float:
        # allocateX overwrites both values with two before top multiplies them.
        return 2.0 * 2.0

    eps = 1e-6
    jvp = (primal(2.0 + eps, 2.0 - 2.0 * eps) - primal(2.0 - eps, 2.0 + 2.0 * eps)) / (2.0 * eps)
    lifecycle = ["allocate(a1)", "allocate(a2)", "multiply", "deallocate(a1)", "deallocate(a2)"]
    return {
        "status": "pass" if close(primal(2.0, 2.0), 4.0) and close(jvp, 0.0) and lifecycle[-2:] == ["deallocate(a1)", "deallocate(a2)"] else "fail",
        "map": "constant four after two helper allocations",
        "jvp": jvp,
        "lifecycle": lifecycle,
    }


def v346() -> dict:
    # This models only defined bounded dispatch facts. The exact source's x is
    # implicit and uninitialized, and cap is a pointer alias, so no derivative
    # claim is made for the source state.
    module_i = 0.0
    ca = ["oink", "oink", "oink"]
    scalar_dispatch = module_i * 3.0
    pointer_dispatch = ca
    return {
        "status": "pass" if close(scalar_dispatch, 0.0) and pointer_dispatch is ca and len(pointer_dispatch) == 3 else "fail",
        "map": "generic foo dispatches scalar and pointer actuals to distinct module procedures",
        "bounded_scalar_result": scalar_dispatch,
        "pointer_alias_preserved": pointer_dispatch is ca,
        "derivative_claim": "none: undefined implicit x and pointer storage identity",
    }


ORACLES = {
    "v346-generic-pointer-boundary": v346,
    "v397-generic-dispatch-map": v397,
    "vpf15-overloaded-derived-difference": vpf15,
    "cm23-allocatable-call-map": cm23,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case")
    args = parser.parse_args()
    values = {args.case: ORACLES[args.case]()} if args.case else {name: fn() for name, fn in ORACLES.items()}
    print(json.dumps(values, indent=2, sort_keys=True))
    return 0 if all(value["status"] == "pass" for value in values.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
