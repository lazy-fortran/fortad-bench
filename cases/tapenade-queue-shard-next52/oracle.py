#!/usr/bin/env python3
"""Independent bounded source-map and refusal oracles for next52."""
from __future__ import annotations

import math
import tomllib
from pathlib import Path


CASE = Path(__file__).resolve().parent
GENERATED = {
    "nonRegressions/set04/v029",
    "nonRegressions/set05/v159",
    "nonRegressions/set05/v160",
    "nonRegressions/set05/v161",
    "nonRegressions/set05/v162",
    "nonRegressions/set05/v163",
    "nonRegressions/set05/v164",
    "nonRegressions/set05/v165",
    "nonRegressions/set05/v166",
    "nonRegressions/set05/v167",
    "nonRegressions/set05/v187",
    "nonRegressions/set05/v212",
    "nonRegressions/set05/v214",
    "nonRegressions/set07/v445",
    "nonRegressions/set07/v456",
    "nonRegressions/set07/v457",
}


def finite_difference(function, value: float) -> float:
    step = 1.0e-6
    return (function(value + step) - function(value - step)) / (2.0 * step)


def check_map(name: str, function, derivative, values: list[float]) -> dict[str, object]:
    checked = [finite_difference(function, value) for value in values]
    expected = [derivative(value) for value in values]
    assert all(math.isclose(a, b, rel_tol=2e-5, abs_tol=2e-7) for a, b in zip(checked, expected))
    return {
        "status": "pass",
        "behavior": {"source_map": name, "sample_primal": [function(value) for value in values]},
        "derivative": {"status": "checked-independent-model-only", "sample_jacobian": expected},
        "refusal": {"status": "not-claimed", "boundary": "no transformed output is read; generated products receive no runtime claim"},
        "source_boundary": "bounded numerical map modeled independently from exact source",
    }


def source_map(path: str) -> dict[str, object]:
    values = [-0.5, 0.5, 1.5, 5.0]
    if path.endswith(("set04/v029", "set05/v212", "set05/v214", "set07/v470")):
        return check_map("exp(x*x)", lambda x: math.exp(x * x), lambda x: 2.0 * x * math.exp(x * x), [-0.5, 0.5, 1.0])
    if path.endswith("set07/v445"):
        return check_map("sin(x)", math.sin, math.cos, values)
    if path.endswith(("set07/v456", "set07/v457")):
        return check_map("2*x", lambda x: 2.0 * x, lambda x: 2.0, values)
    if path.endswith("set05/v159"):
        return check_map("abs(x-0.25)", lambda x: abs(x - 0.25), lambda x: -1.0 if x < 0.25 else 1.0, [-1.0, 0.0, 1.0])
    if path.endswith("set05/v160"):
        function = lambda x: 15.0 * (x + 1.0) if x > 1.0 else 5.0 * (x + 1.0)
        return check_map("masked sequential scaling", function, lambda x: 15.0 if x > 1.0 else 5.0, [-0.5, 0.5, 1.5, 3.0])
    if path.endswith("set05/v161"):
        return check_map("masked overwrite x+6", lambda x: x + 6.0, lambda x: 1.0, values)
    if path.endswith(("set05/v162", "set05/v164")):
        function = lambda x: x + 5.0 if x > 1.0 else x + 8.0
        return check_map("nested masked affine map", function, lambda x: 1.0, [-0.5, 0.5, 1.5, 3.0])
    if path.endswith("set05/v163"):
        function = lambda x: x + 5.0 if x > 1.0 else x + 8.0
        return check_map("nested masked overwrite", function, lambda x: 1.0, [-0.5, 0.5, 1.5, 3.0])
    if path.endswith("set05/v165"):
        function = lambda x: 5.0 * x if x > 1.0 else 8.0 * x
        return check_map("nested masked multiplicative map", function, lambda x: 5.0 if x > 1.0 else 8.0, [-0.5, 0.5, 1.5, 3.0])
    if path.endswith("set05/v166"):
        function = lambda x: x + 7.0 if x > 1.0 else x + 8.0
        return check_map("deep nested masked affine map", function, lambda x: 1.0, [-0.5, 0.5, 1.5, 3.0])
    if path.endswith("set05/v167"):
        function = lambda x: 15.0 * math.log(2.0 * x) if x > 1.0 else 5.0 * (x + 1.0)
        return check_map("masked logarithmic map", function, lambda x: 15.0 / x if x > 1.0 else 5.0, [-0.5, 0.5, 1.5, 3.0])
    if path.endswith("set05/v187"):
        function = lambda x: 3.0 * x if x > 4.0 else x
        return check_map("nested masked scale", function, lambda x: 3.0 if x > 4.0 else 1.0, [-0.5, 0.5, 1.5, 5.0])
    raise AssertionError(f"no independent source map for {path}")


def refusal(classification: str) -> dict[str, object]:
    return {
        "status": "pass",
        "behavior": {"source_behavior": "exact source retained; no repaired source or transformed output used"},
        "derivative": {"status": "not-claimed"},
        "refusal": {"status": "expected", "boundary": classification},
        "source_boundary": "independent refusal oracle records source/engine boundary only",
    }


def main() -> int:
    selected = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))["case"]
    values = {}
    for item in selected:
        values[item["oracle_case"]] = source_map(item["queue_path"]) if item["queue_path"] in GENERATED else refusal(item["classification"])
    import json
    print(json.dumps(values, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
