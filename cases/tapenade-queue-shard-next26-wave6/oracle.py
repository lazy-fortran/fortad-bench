#!/usr/bin/env python3
"""Independent bounded behavioral/refusal oracles for next26 wave6."""

from __future__ import annotations

import argparse
import json
import math


def close(actual: float, expected: float) -> bool:
    return math.isclose(actual, expected, rel_tol=1e-6, abs_tol=1e-6)


def lh113() -> dict:
    def primal(state: list[float]) -> tuple[list[float], float, list[float]]:
        values = list(state)
        contents = [math.sin(value) for value in values[:9]]
        obj = 12.5
        for index in range(10):
            values[index] = values[index] * values[index + 1]
            obj += values[index] * obj
        obj = math.sin(obj) + 2.0 * sum(contents[:5])
        return values, obj, contents

    state = [0.1 * (index + 1) for index in range(11)]
    direction = [(-1.0) ** index * 0.03 for index in range(11)]
    eps = 1e-6
    _, value, contents = primal(state)
    plus = primal([x + eps * dx for x, dx in zip(state, direction)])[1]
    minus = primal([x - eps * dx for x, dx in zip(state, direction)])[1]
    jvp = (plus - minus) / (2.0 * eps)
    return {
        "status": "pass" if len(contents) == 9 and math.isfinite(value) and math.isfinite(jvp) else "fail",
        "map": "foo: BAR sin prepass, sequential state update, then GEE scalar accumulation",
        "output": value,
        "jvp": jvp,
        "derivative_claim": "bounded primal/JVP only; no exact FortAD support claim for module allocatable state",
    }


def ompl07() -> dict:
    def primal(values: list[float]) -> list[float]:
        result = [0.0] * len(values)
        for index in range(1, len(values) - 1):
            result[index] = values[index - 1] + values[index + 1] - 2.0 * values[index]
        return result

    values = [0.2, -0.4, 0.7, 1.1, -0.3]
    direction = [0.1, -0.2, 0.3, -0.4, 0.5]
    eps = 1e-6
    jvp = [
        (a - b) / (2.0 * eps)
        for a, b in zip(
            primal([x + eps * dx for x, dx in zip(values, direction)]),
            primal([x - eps * dx for x, dx in zip(values, direction)]),
        )
    ]
    expected = [0.0] + [direction[i - 1] + direction[i + 1] - 2.0 * direction[i] for i in range(1, 4)] + [0.0]
    return {
        "status": "pass" if all(close(a, b) for a, b in zip(jvp, expected)) else "fail",
        "map": "stencil_nodefault(r,u,n): r(i)=u(i-1)+u(i+1)-2*u(i)",
        "jvp": jvp,
        "derivative_claim": "bounded stencil oracle only; OpenMP directive support is not claimed",
    }


def v179() -> dict:
    # The selected root has character/integer arguments and optional outputs;
    # its only numeric-looking branch is an undefined logical guard around
    # WRITE. Do not invent a numeric map or derivative for it.
    return {
        "status": "pass",
        "map": "no defined numeric output map: optional character outputs and WRITE-only debug branch",
        "defined_numeric_outputs": [],
        "derivative_claim": "none",
    }


def v341() -> dict:
    def crunch(x: list[float], y: list[float]) -> list[float]:
        result = list(x)
        result[1] = result[2] * result[1]
        result[3] = result[3] + y[4] * y[0]
        return result

    x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    y = [0.5] * 10
    prefix = crunch(x, y)
    return {
        "status": "pass" if close(prefix[1], 6.0) and close(prefix[3], 4.25) else "fail",
        "map": "defined first crunch(A,B) prefix before top assigns unallocated C%ff/C%gg",
        "defined_prefix": prefix,
        "undefined_boundary": "top assigns unallocated allocatable derived-type components",
        "derivative_claim": "none for exact top beyond the bounded defined prefix",
    }


ORACLES = {
    "lh113-foo-map": lh113,
    "ompl07-stencil-map": ompl07,
    "v179-no-numeric-map": v179,
    "v341-allocatable-boundary": v341,
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
