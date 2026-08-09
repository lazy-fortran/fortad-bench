#!/usr/bin/env python3
"""Independent bounded source-map and refusal oracles for next51."""
from __future__ import annotations

import argparse
import math
import tomllib
from pathlib import Path


CASE = Path(__file__).resolve().parent
GENERATED = {
    "nonRegressions/set06/v286": "internal quadratic function map",
    "nonRegressions/set03/lh085": "masked WHERE affine map",
    "nonRegressions/set04/lh195": "two-term quadratic cost map",
    "nonRegressions/set04/v011": "host-associated internal-function map",
}


def finite_difference(function, value: float) -> float:
    step = 1.0e-6
    return (function(value + step) - function(value - step)) / (2.0 * step)


def source_map(path: str) -> dict[str, object]:
    if path.endswith("set06/v286"):
        value = 1.75
        primal = value * value
        jacobian = 2.0 * value
        checked = finite_difference(lambda x: x * x, value)
        assert math.isclose(jacobian, checked, rel_tol=1e-6)
    elif path.endswith("set03/lh085"):
        values = [0.5, 2.0, 5.0, -1.0]
        primal = [x + 6.0 if x <= 1.0 else x + 3.0 for x in values]
        jacobian = [1.0] * len(values)
        checked = [finite_difference(lambda x: x + (6.0 if x <= 1.0 else 3.0), x) for x in values]
        assert all(math.isclose(a, b, rel_tol=1e-6) for a, b in zip(jacobian, checked))
    elif path.endswith("set04/lh195"):
        values = [1.0, 2.0, 3.0]
        primal = 0.5 * (values[0] ** 2 + values[1] ** 2) + 0.5 * (values[1] ** 2 + values[2] ** 2)
        jacobian = [values[0], 2.0 * values[1], values[2]]
        checked = [
            finite_difference(
                lambda x, index=index: 0.5 * ((x if index == 0 else values[0]) ** 2 + (x if index == 1 else values[1]) ** 2)
                + 0.5 * ((x if index == 1 else values[1]) ** 2 + (x if index == 2 else values[2]) ** 2),
                values[index],
            )
            for index in range(3)
        ]
        assert all(math.isclose(a, b, rel_tol=1e-6) for a, b in zip(jacobian, checked))
    else:
        host_x = 1.5
        argument = 2.0
        primal = argument + host_x
        jacobian = 1.0
        checked = finite_difference(lambda x: x + host_x, argument)
        assert math.isclose(jacobian, checked, rel_tol=1e-6)
    return {
        "status": "pass",
        "behavior": {"source_map": GENERATED[path], "sample_primal": primal},
        "derivative": {"status": "checked-independent-model-only", "sample_jacobian": jacobian},
        "refusal": {"status": "not-claimed", "boundary": "no transformed output is read; generated products receive no runtime claim"},
        "source_boundary": "bounded numerical map modeled independently from exact source",
    }


def refusal(path: str, classification: str) -> dict[str, object]:
    return {
        "status": "pass",
        "behavior": {"source_behavior": "exact source retained; no repaired source or transformed output used"},
        "derivative": {"status": "not-claimed"},
        "refusal": {"status": "expected", "boundary": classification},
        "source_boundary": "independent refusal oracle records source/engine boundary only",
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
    values = {}
    for item in selected:
        values[item["oracle_case"]] = source_map(item["queue_path"]) if item["queue_path"] in GENERATED else refusal(item["queue_path"], item["classification"])
    import json
    print(json.dumps(values, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
