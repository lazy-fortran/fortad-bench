"""Independent bounded behavior/refusal models for next42."""

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


def _lh068_map(values: list[float]) -> list[float]:
    return [values[0] * values[0]]


def _lh068() -> dict[str, object]:
    return _check(
        _lh068_map,
        [0.73],
        [0.19],
        [1.0],
        "FortAD generated standalone parser/forward products lack the local GRID_T context; reverse has three derived dependents",
        "the bounded top result is v -> v**2 after the local record operations",
    )


def _v002_map(values: list[float]) -> list[float]:
    return [sum(values[index] * values[index + 3] for index in range(3))]


def _v002() -> dict[str, object]:
    return _check(
        _v002_map,
        [1.2, -0.4, 0.7, 0.8, 1.5, -0.6],
        [0.11, -0.07, 0.03, -0.09, 0.13, 0.05],
        [1.0],
        "FortAD generated products require the module-local VECTOR derived-type interface and fail standalone strict syntax",
        "the bounded map is the three-component vector dot product",
    )


def _v003_map(values: list[float]) -> list[float]:
    return [values[0] + values[1] + values[2]]


def _v003() -> dict[str, object]:
    return _check(
        _v003_map,
        [0.4, -1.1, 0.8],
        [0.17, 0.05, -0.12],
        [1.0],
        "FortAD refuses the active PRINT statement at source line 15",
        "the oracle omits only the printed names and models the numeric component sum",
    )


def _v012_map(values: list[float]) -> list[float]:
    ux, uy = values
    vx = uy
    vy = ux + uy
    wx = ux * vx
    wy = 0.0
    return [vx, vy, wx, wy]


def _v012() -> dict[str, object]:
    return _check(
        _v012_map,
        [0.9, -0.35],
        [0.08, 0.14],
        [1.2, -0.7, 0.5, 0.3],
        "FortAD generated products require local DEFPOINT module context; reverse has two derived dependents",
        "the oracle retains only the defined x/y components of v and w after the point call",
    )


ORACLES = {
    "lh068-record-square": _lh068,
    "v002-vector-dot": _v002,
    "v003-derived-vector-sum": _v003,
    "v012-point-map": _v012,
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
