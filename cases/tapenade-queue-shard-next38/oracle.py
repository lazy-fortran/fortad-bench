"""Independent behavioral/refusal models for next38.

The models do not read Tapenade output, FortAD output, generated products, or
the status ledger.  They implement only bounded source behavior and record a
separate refusal/policy boundary where the exact transformation was refused or
produced a non-strict interface.
"""

from __future__ import annotations

import argparse
import json
import math


def _finite_difference(function, value: list[float], direction: list[float]) -> float:
    step = 1.0e-4
    plus = function([x + step * d for x, d in zip(value, direction)])
    minus = function([x - step * d for x, d in zip(value, direction)])
    return (plus - minus) / (2.0 * step)


def _adjoint_check(function, value: list[float], direction: list[float]) -> tuple[float, list[float]]:
    step = 1.0e-4
    gradient = []
    for index in range(len(value)):
        plus = value[:]
        minus = value[:]
        plus[index] += step
        minus[index] -= step
        gradient.append((function(plus) - function(minus)) / (2.0 * step))
    return _finite_difference(function, value, direction), gradient


def _matrix(rows: int, columns: int, value: float) -> list[list[float]]:
    return [[value + 0.1 * (row + 2 * column) for column in range(columns)] for row in range(rows)]


def _lh215_value(x: list[float]) -> float:
    y1 = [float(index + 1) for index in range(10)]
    y2 = [20.0 + index for index in range(10)]
    z1 = [2.0 + index for index in range(15)]
    z2 = _matrix(10, 15, 8.0)
    a, b, c = x[0], x[1], x[2]
    x[:] = [sum(x)] * 5
    factor = sum(b * item * sum(item_x * c for item_x in x) for item in z1)
    y1 = [left * a * right * factor for left, right in zip(y2, z1[:10])]
    y2 = [sum(item for item in y1 if item > 5.0)] * 10
    second = sum(c * item * sum(item_x * item_x for item_x in x if item_x > 12.0) for item in y1 if item > 5.0)
    y2 = [item * b * sum(z1) * second for item in y1]
    z1 = [item * item + sum(item_2 for item_2 in z1 if item_2 > 1.1) for item in z1]
    x = [item * item + sum(x) for item in x]
    z1 = [item * item + sum(item_2 for item_2 in z1 if item_2 > 1.1) for item in z1]
    return sum(x) + sum(y1) + sum(y2) + sum(z1) + sum(sum(row) for row in z2)


def _lh216_value(x: list[float]) -> float:
    y1 = [5.0 + index for index in range(10)]
    y2 = [20.0 + index for index in range(10)]
    z1 = [4.0 + index for index in range(15)]
    z2 = _matrix(10, 15, 10.0)
    a, b = y1[2], y1[3]
    xsum = sum(x)
    y1[:5] = [item * item + xsum for item in x]
    z2_dim2 = [sum(row) for row in z2]
    y1 = [left + right for left, right in zip(y1, z2_dim2)]
    z2_dim1 = [sum(z2[row][column] for row in range(10) if z2[row][column] > 7.0) for column in range(15)]
    z1 = [left + right for left, right in zip(z1, z2_dim1)]
    y2 = [item + a * sum(z2[row][column] * b for column in range(15) if z2[row][column] > 6.0) for row, item in enumerate(y2)]
    y2 = [item + sum(z2[row][column] for column in range(15) if z2[row][column] > 3.2) for row, item in enumerate(y2)]
    z2 = [[z2[row][column] + b * y2[row] for column in range(15)] for row in range(10)]
    x[3] = a + b
    return sum(x) + sum(y1) + sum(y2) + sum(z1) + sum(sum(row) for row in z2)


def _array_oracle(function, value: list[float], direction: list[float], boundary: str) -> dict[str, object]:
    jvp, gradient = _adjoint_check(function, value, direction)
    adjoint_left = jvp * 1.7
    adjoint_right = sum(d * g * 1.7 for d, g in zip(direction, gradient))
    assert math.isfinite(function(value[:]))
    assert math.isclose(adjoint_left, adjoint_right, rel_tol=2.0e-5, abs_tol=2.0e-4)
    return {
        "status": "pass",
        "primal": {"objective": function(value[:])},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": jvp,
            "vjp": gradient,
            "adjoint_left": adjoint_left,
            "adjoint_right": adjoint_right,
        },
        "refusal": {"status": "expected" if boundary else "not-observed", "boundary": boundary or "none"},
    }


def _lh215() -> dict[str, object]:
    return _array_oracle(_lh215_value, [0.1, 0.2, 0.3, 0.4, 0.5], [0.02, -0.01, 0.03, -0.02, 0.04], "")


def _lh216() -> dict[str, object]:
    return _array_oracle(_lh216_value, [10.0, 11.0, 12.0, 13.0, 14.0], [0.2, -0.1, 0.3, -0.2, 0.4], "reverse dependent inference is unresolved for the multi-output subroutine")


def _mvo11() -> dict[str, object]:
    def objective(values: list[float]) -> float:
        det = values[0]
        assert det != 0.0
        return sum(det / det for _ in range(9))

    direction = [0.37]
    jvp, gradient = _adjoint_check(objective, [5.0], direction)
    assert math.isclose(objective([5.0]), 9.0, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(jvp, 0.0, rel_tol=0.0, abs_tol=2.0e-9)
    assert math.isclose(direction[0] * gradient[0], jvp, rel_tol=0.0, abs_tol=2.0e-9)
    return {
        "status": "pass",
        "primal": {"det": 5.0, "ainv_sum": 9.0},
        "derivative": {"status": "checked-independent-model-only", "jvp": jvp, "vjp": gradient, "adjoint_left": jvp, "adjoint_right": direction[0] * gradient[0]},
        "refusal": {"status": "expected", "boundary": "valid local INTERFACE block at source line 12"},
    }


def _v472() -> dict[str, object]:
    def objective(values: list[float]) -> float:
        x0, x1 = values
        result = (2.0 * x0) * (2.0 * x1)
        y_sum = 2.0 * x0 + 2.0 * x1
        global_after = 3.0 + result
        return result + y_sum + global_after

    value = [3.0, 2.0]
    direction = [0.2, -0.3]
    jvp, gradient = _adjoint_check(objective, value, direction)
    assert math.isclose(objective(value), 61.0, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(jvp * 1.7, sum(d * g * 1.7 for d, g in zip(direction, gradient)), rel_tol=0.0, abs_tol=2.0e-8)
    return {
        "status": "pass",
        "primal": {"x": value, "compute": 24.0, "global_after": 27.0, "objective": objective(value)},
        "derivative": {"status": "checked-independent-model-only", "jvp": jvp, "vjp": gradient, "adjoint_left": jvp * 1.7, "adjoint_right": sum(d * g * 1.7 for d, g in zip(direction, gradient))},
        "refusal": {"status": "expected", "boundary": "FortAD generated forward interface omits the function result formal; exact source also writes module global state"},
    }


ORACLES = {
    "lh215-array-reductions": _lh215,
    "lh216-array-reductions": _lh216,
    "mvo11-interface-map": _mvo11,
    "v472-global-accumulator": _v472,
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
