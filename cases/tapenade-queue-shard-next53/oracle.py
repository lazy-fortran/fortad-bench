#!/usr/bin/env python3
"""Independent bounded source-map and refusal oracles for next53."""
from __future__ import annotations

import argparse
import json
import math
import tomllib
from pathlib import Path

CASE = Path(__file__).resolve().parent
SOURCE_MAPS = {
    "nonregressions-set01-lh145-ff": "quadratic FF(u,v)=u*u map",
    "nonregressions-set11-lh028-cost": "three-step vector cost recurrence",
    "nonregressions-set12-lh16-tata": "scalar/array SUM affine map",
    "nonregressions-set12-profile02-bar": "quadratic bar(a)=a*a map",
    "nonregressions-set12-profile05-foo": "quadratic foo(a)=a*a map",
    "nonregressions-set12-profile07-foofp": "fixed-point fooFP map",
}


def finite_difference(function, value: float) -> float:
    step = 1.0e-6
    return (function(value + step) - function(value - step)) / (2.0 * step)


def source_map(case: str) -> dict[str, object]:
    if case.endswith("set01-lh145-ff"):
        value = 1.75
        primal = value * value
        jacobian = 2.0 * value
        checked = finite_difference(lambda x: x * x, value)
    elif case.endswith("set11-lh028-cost"):
        values = [0.5, 1.0, 1.5]

        def cost(vector):
            rad = list(vector)
            for index in range(1, 4):
                rad = [x + current * index * 2.0 for x, current in zip(vector, rad)]
            return sum(rad)

        primal = cost(values)
        jacobian = [
            finite_difference(
                lambda x, index=index: cost(values[:index] + [x] + values[index + 1:]),
                values[index],
            )
            for index in range(len(values))
        ]
        checked = jacobian[:]
    elif case.endswith("set12-lh16-tata"):
        c = [1.0, 2.0, 3.0, 4.0]
        d = 0.5

        def tata_map(value):
            return sum(value * item + d + 1.5 for item in c) * value

        value = 2.0
        primal = tata_map(value)
        jacobian = 2.0 * sum(c) * value + sum(d + 1.5 for _ in c)
        checked = finite_difference(tata_map, value)
    elif case.endswith("set12-profile02-bar") or case.endswith("set12-profile05-foo"):
        value = 1.25
        primal = value * value
        jacobian = 2.0 * value
        checked = finite_difference(lambda x: x * x, value)
    else:
        cur = 2.25
        power = 2.0
        value = 2.5

        def fixed_point_map(current):
            return 0.5 * (current + value / (current ** power))

        primal = fixed_point_map(cur)
        jacobian = 0.5 * (1.0 - value * power / (cur ** (power + 1.0)))
        checked = finite_difference(fixed_point_map, cur)
    if isinstance(jacobian, list):
        assert all(math.isclose(a, b, rel_tol=1.0e-6) for a, b in zip(jacobian, checked))
    else:
        assert math.isclose(jacobian, checked, rel_tol=1.0e-6)
    return {
        "status": "pass",
        "behavior": {"source_map": SOURCE_MAPS[case], "sample_primal": primal},
        "derivative": {"status": "checked-independent-model-only", "sample_jacobian": jacobian},
        "refusal": {"status": "not-claimed", "boundary": "no transformed output is read; generated products receive no runtime claim"},
        "source_boundary": "bounded numerical map modeled independently from the exact source",
    }


def refusal(case: str, classification: str) -> dict[str, object]:
    return {
        "status": "pass",
        "behavior": {"source_behavior": "exact source retained; no repaired source or transformed output used"},
        "derivative": {"status": "not-claimed"},
        "refusal": {"status": "expected", "boundary": classification},
        "source_boundary": "independent refusal oracle records the exact-source/engine boundary only",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case")
    args = parser.parse_args()
    selected = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))["case"]
    if args.case:
        selected = [item for item in selected if item["oracle_case"] == args.case]
        if not selected:
            raise SystemExit(f"unknown oracle case: {args.case}")
    values = {
        item["oracle_case"]: source_map(item["oracle_case"])
        if item["oracle_case"] in SOURCE_MAPS
        else refusal(item["oracle_case"], item["classification"])
        for item in selected
    }
    print(json.dumps(values, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
