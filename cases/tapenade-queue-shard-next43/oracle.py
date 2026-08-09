"""Independent bounded behavior/refusal models for next43."""

from __future__ import annotations

import argparse
import json
import math
from collections.abc import Callable


VectorMap = Callable[[list[float]], list[float]]


def _objective(function: VectorMap, value: list[float], weights: list[float]) -> float:
    return sum(weight * item for weight, item in zip(weights, function(value[:])))


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
    source_boundary: str,
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
    return {
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
        "source_boundary": source_boundary,
    }


def _v018_map(values: list[float]) -> list[float]:
    return [values[0] + values[1] + values[2]]


def _v018() -> dict[str, object]:
    return _check(
        _v018_map,
        [0.4, -0.8, 1.25],
        [0.17, 0.05, -0.12],
        [1.0],
        "FortAD refuses the active PRINT statement at source line 18",
        "the bounded model keeps the numeric a%x+b%x+u%z sum and omits printed names",
    )


def _v043_map(values: list[float]) -> list[float]:
    return [values[0] + values[1]]


def _v043() -> dict[str, object]:
    return _check(
        _v043_map,
        [1.2, -0.35],
        [0.08, 0.14],
        [1.0],
        "FortAD refuses the active derived object because T must name a real component",
        "the bounded model is FF(T)=T%LOWER+T%UPPER",
    )


def _v496_map(values: list[float]) -> list[float]:
    return [values[0] * values[2] + values[1] * values[3]]


def _v496() -> dict[str, object]:
    return _check(
        _v496_map,
        [1.2, -0.4, 0.8, 1.5],
        [0.11, -0.07, -0.09, 0.13],
        [1.0],
        "FortAD refuses the local INTERFACE statement at source line 12",
        "the bounded callback model evaluates a two-component dot product",
    )


def _lh238_map(values: list[float]) -> list[float]:
    return [1.5 * values[0], 1.5 * values[0], 1.5 * values[0]]


def _lh238() -> dict[str, object]:
    return _check(
        _lh238_map,
        [0.73],
        [0.19],
        [1.2, -0.7, 0.5],
        "FortAD refuses the derived-type declaration at source line 1",
        "the bounded loop model initializes f1 to 1.5 and returns three 1.5*x values",
    )


ORACLES = {
    "v018-derived-sum": _v018,
    "v043-derived-sum": _v043,
    "v496-callback-dot": _v496,
    "lh238-scaled-vector": _lh238,
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
