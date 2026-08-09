"""Independent behavioral/refusal models for next39.

The models do not read Tapenade output, FortAD output, generated products, or
the status ledger.  They implement bounded source behavior and record either
the observed FortAD refusal or the no-runtime evidence boundary separately.
"""

from __future__ import annotations

import argparse
import json
import math


def _finite_difference(function, value: list[float], direction: list[float]) -> float:
    step = 1.0e-5
    plus = function([x + step * d for x, d in zip(value, direction)])
    minus = function([x - step * d for x, d in zip(value, direction)])
    return (plus - minus) / (2.0 * step)


def _adjoint_check(function, value: list[float], direction: list[float]) -> tuple[float, list[float]]:
    step = 1.0e-5
    gradient = []
    for index in range(len(value)):
        plus = value[:]
        minus = value[:]
        plus[index] += step
        minus[index] -= step
        gradient.append((function(plus) - function(minus)) / (2.0 * step))
    return _finite_difference(function, value, direction), gradient


def _check(function, value: list[float], direction: list[float], boundary: str) -> dict[str, object]:
    jvp, gradient = _adjoint_check(function, value, direction)
    left = 1.3 * jvp
    right = sum(1.3 * d * g for d, g in zip(direction, gradient))
    assert math.isfinite(function(value[:]))
    assert math.isclose(left, right, rel_tol=2.0e-5, abs_tol=2.0e-5)
    return {
        "status": "pass",
        "primal": {"objective": function(value[:])},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": jvp,
            "vjp": gradient,
            "adjoint_left": left,
            "adjoint_right": right,
        },
        "refusal": {"status": "expected" if boundary else "not-observed", "boundary": boundary or "none"},
    }


def _v297_value(values: list[float]) -> float:
    def test1(value: float) -> float:
        if value > 0.0:
            value = -value
            return test1(value)
        return value

    return test1(values[0])


def _v297() -> dict[str, object]:
    return _check(_v297_value, [3.0], [0.37], "reverse dependent inference in the mutually recursive TEST1/TEST2 call graph")


def _vpf06_value(values: list[float]) -> float:
    i1, i2 = values
    return i1 / i2


def _vpf06() -> dict[str, object]:
    return _check(_vpf06_value, [6.0, 2.0], [0.2, -0.3], "reverse dependent inference across overloaded HEAD interfaces")


def _v173_value(values: list[float]) -> float:
    n = 4
    a = values[0:n]
    b = values[n:2 * n]
    c = values[2 * n:3 * n]
    x = values[3 * n]
    t = values[3 * n + 1:4 * n + 1]
    positive_t_sum = sum(item for item in t if item > 0.0)
    for index in range(n):
        if b[index] > 0.0:
            c[index] += positive_t_sum
            a[index] = b[index] + x
            b[index] = 2.0 * b[index] - 8.0
    return sum(a) + sum(b) + sum(c)


def _v173() -> dict[str, object]:
    value = [1.0, 2.0, 3.0, 4.0, 1.0, -2.0, 3.0, -4.0, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, -1.0, 2.0, -3.0, 4.0]
    direction = [0.1, -0.2, 0.15, -0.1, 0.2, 0.1, -0.15, 0.1, -0.05, 0.02, -0.03, 0.04, 0.01, 0.1, -0.05, 0.08, -0.04, 0.03]
    return _check(_v173_value, value, direction, "no transformed-product runtime or exact-source derivative claim")


def _lh150_value(values: list[float]) -> float:
    x, y = values
    n = 3
    u1_sum = x * n * (n + 1) / 2.0
    y = y + u1_sum
    x = 2.0 * x * (values[1])
    x += n * y * (values[0] * values[1])
    return x + 0.5 * y


def _lh150() -> dict[str, object]:
    return _check(_lh150_value, [1.5, 2.0], [0.2, -0.1], "multiple local allocatable allocation/deallocation lifetime")


ORACLES = {
    "v297-recursive-sign-flip": _v297,
    "vpf06-quotient": _vpf06,
    "v173-where-map": _v173,
    "lh150-allocation-map": _lh150,
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
