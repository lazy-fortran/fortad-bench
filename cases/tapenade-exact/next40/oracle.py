"""Independent behavioral/refusal models for next40.

These models do not read Tapenade output, FortAD output, generated products,
or the status ledger.  They model only the bounded numeric map visible in the
exact source and keep the observed FortAD refusal or unsafe-source boundary
separate from the derivative check.
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
    step = 1.0e-5
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
    step = 1.0e-5
    for index in range(len(value)):
        plus = value[:]
        minus = value[:]
        plus[index] += step
        minus[index] -= step
        gradient.append((scalar(plus) - scalar(minus)) / (2.0 * step))
    left = 1.3 * jvp
    right = sum(1.3 * delta * derivative for delta, derivative in zip(direction, gradient))
    assert all(math.isfinite(item) for item in primal)
    assert math.isclose(left, right, rel_tol=2.0e-5, abs_tol=2.0e-5)
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


def _component_map(values: list[float], size: int, selected: tuple[int, ...]) -> list[float]:
    c = values[:size]
    d = values[size:2 * size]
    result = [0.0] * size
    for index in selected:
        result[index] = c[index] * d[index]
    return result


def _v098() -> dict[str, object]:
    return _check(
        lambda values: _component_map(values, 2, (0, 1)),
        [1.2, -0.7, 2.5, 1.1],
        [0.2, -0.3, 0.4, 0.15],
        [1.3, -0.8],
        "FortAD refuses the legacy derived-type declaration at source line 1",
    )


def _v099() -> dict[str, object]:
    return _check(
        lambda values: _component_map(values, 2, (0, 1)),
        [0.9, 1.6, -1.2, 2.0],
        [-0.1, 0.25, 0.3, -0.2],
        [0.7, 1.1],
        "FortAD refuses the legacy derived-type declaration at source line 1",
    )


def _v100() -> dict[str, object]:
    return _check(
        lambda values: _component_map(values, 6, (0, 2)),
        [1.0, -0.5, 2.0, 0.25, -1.2, 0.8, 1.5, -2.0, 0.75, 1.2, -0.4, 2.5],
        [0.2, 0.1, -0.15, 0.3, -0.2, 0.05, -0.1, 0.25, 0.2, -0.3, 0.15, 0.1],
        [1.1, -0.4, 0.8, 0.2, -0.6, 0.9],
        "FortAD refuses the legacy derived-type declaration at source line 1",
    )


def _v263_map(values: list[float]) -> list[float]:
    p = values[:5]
    hv = values[5]
    dh = -0.38 * hv
    p_out = [dh * item for item in p]
    a = [3.0 * item for item in p_out]
    c = [4.0 * item for item in p_out]
    return [*p_out, *a, *c, dh]


def _v263() -> dict[str, object]:
    return _check(
        _v263_map,
        [1.0, -0.5, 2.0, 0.75, -1.25, 1.4],
        [0.1, -0.2, 0.15, -0.05, 0.08, 0.12],
        [1.0, -0.4, 0.2, 0.6, -0.3, 0.5, 0.7, -0.2, 0.3, 0.4, -0.1, 0.2, 0.5, -0.6, 0.8, 0.9],
        "FortAD reverse cannot infer a single dependent among A, C, DH, and TMP1",
        "the exact source writes TMP1(1,1,1) while TMP1 is unallocated; the oracle models assignments before that side effect",
    )


ORACLES = {
    "v098-component-section": _v098,
    "v099-component-section": _v099,
    "v100-strided-component-section": _v100,
    "v263-allocatable-component-map": _v263,
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
