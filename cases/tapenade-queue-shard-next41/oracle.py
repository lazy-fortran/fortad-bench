"""Independent bounded behavior/refusal models for next41.

The models do not read Tapenade output, FortAD output, generated products, or
the status ledger.  They check only arithmetic maps that can be stated
independently of the exact source's refused ownership or declaration boundary.
"""

from __future__ import annotations

import argparse
import json
import math
from collections.abc import Callable


VectorMap = Callable[[list[float]], list[float]]


def _objective(function: VectorMap, value: list[float], weights: list[float]) -> float:
    output = function(value[:])
    return sum(weight * item for weight, item in zip(weights, output))


def _finite_difference(function: Callable[[list[float]], float], value: list[float], direction: list[float]) -> float:
    step = 1.0e-6
    plus = function([item + step * delta for item, delta in zip(value, direction)])
    minus = function([item - step * delta for item, delta in zip(value, direction)])
    return (plus - minus) / (2.0 * step)


def _check(
    function: VectorMap,
    value: list[float],
    direction: list[float],
    weights: list[float],
    boundary: str,
    source_boundary: str | None = None,
) -> dict[str, object]:
    scalar = lambda point: _objective(function, point, weights)
    primal = function(value[:])
    jvp = _finite_difference(scalar, value, direction)
    gradient = []
    step = 1.0e-6
    for index in range(len(value)):
        plus = value[:]
        minus = value[:]
        plus[index] += step
        minus[index] -= step
        gradient.append((scalar(plus) - scalar(minus)) / (2.0 * step))
    left = 1.7 * jvp
    right = sum(1.7 * delta * derivative for delta, derivative in zip(direction, gradient))
    assert all(math.isfinite(item) for item in primal)
    assert math.isclose(left, right, rel_tol=4.0e-5, abs_tol=4.0e-5)
    result: dict[str, object] = {
        "status": "pass",
        "primal": {"output": primal, "objective": scalar(value[:])},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": jvp,
            "vjp": gradient,
            "adjoint_left": left,
            "adjoint_right": right,
        },
        "refusal": {"status": "expected", "boundary": boundary},
    }
    if source_boundary:
        result["source_boundary"] = source_boundary
    return result


def _v371_map(values: list[float]) -> list[float]:
    x, v = values
    return [v * sum(math.sin(x * index) for index in range(1, 11))]


def _v371() -> dict[str, object]:
    return _check(
        _v371_map,
        [0.31, 1.4],
        [0.07, -0.13],
        [1.0],
        "FortAD refuses module-level allocatable mutable state",
        "the exact TOP source writes the module allocatable T without establishing dummy ownership; the oracle models the intended allocated length-10 map",
    )


def _v372_map(values: list[float]) -> list[float]:
    x = values[0]
    return [sum(math.sin(x * index) for index in range(1, 11))]


def _v372() -> dict[str, object]:
    return _check(
        _v372_map,
        [0.27],
        [-0.11],
        [1.0],
        "FortAD refuses module-level allocatable mutable state",
        "the exact TOP source writes the module allocatable T without establishing dummy ownership; the oracle models the intended allocated length-10 map",
    )


def _v396_map(values: list[float]) -> list[float]:
    a, x = values
    return [6.0 * a, x**4]


def _v396() -> dict[str, object]:
    return _check(
        _v396_map,
        [0.8, 1.2],
        [0.12, -0.08],
        [0.9, -1.1],
        "FortAD refuses module-level allocatable mutable state",
        "the exact source also uses GLOBAL(0); the oracle models only the stated intended state-free result of five unit increments and two squarings",
    )


def _v403_map(values: list[float]) -> list[float]:
    c = values[:2]
    d = values[2:]
    return [c[index] * d[index] for index in range(2)]


def _v403() -> dict[str, object]:
    return _check(
        _v403_map,
        [1.2, -0.7, 2.5, 1.1],
        [0.2, -0.3, 0.4, 0.15],
        [1.3, -0.8],
        "FortAD refuses the local derived-type declaration at source line 1",
    )


ORACLES = {
    "v371-module-allocatable-map": _v371,
    "v372-module-allocatable-map": _v372,
    "v396-global-state-intended-map": _v396,
    "v403-derived-component-product": _v403,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = [args.case] if args.case else sorted(ORACLES)
    values = {name: ORACLES[name]() for name in selected}
    print(json.dumps(values, indent=2, sort_keys=True))
    return 0 if all(value["status"] == "pass" for value in values.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
