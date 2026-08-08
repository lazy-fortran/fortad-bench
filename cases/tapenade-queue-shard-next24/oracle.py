#!/usr/bin/env python3
"""Independent behavioral oracles for the next24 exact-source boundaries."""

from __future__ import annotations

import argparse
import json
import math


def _finite_difference(function, values: list[float], direction: list[float]) -> float:
    step = 1.0e-6
    plus = [value + step * delta for value, delta in zip(values, direction)]
    minus = [value - step * delta for value, delta in zip(values, direction)]
    return (function(plus) - function(minus)) / (2.0 * step)


def v398() -> dict[str, object]:
    """Model the defined diagonal pointer update and scalar product."""
    n = 2

    def evaluate(values: list[float]) -> float:
        factor = 5.0 * values[0]
        result = 1.0
        for _ in range(n):
            for _ in range(3):
                result *= factor * math.sin(factor)
        return result

    values = [0.5]
    direction = [0.07]
    output = evaluate(values)
    jvp = _finite_difference(evaluate, values, direction)
    factor = 5.0 * values[0]
    analytic = output * (3 * n) * (1.0 / values[0] + 5.0 * math.cos(factor) / math.sin(factor))
    seed = 1.25
    vjp = seed * analytic
    assert math.isclose(jvp, direction[0] * analytic, rel_tol=2.0e-8)
    assert math.isfinite(output) and math.isfinite(vjp)
    return {
        "status": "pass",
        "outputs": {"y": output, "finite_difference_jvp": jvp},
        "vjp": {"x": vjp},
        "boundary": "nested pointer-owned derived components and target identity are outside the exact generated-source contract",
    }


def v529() -> dict[str, object]:
    """Model compute with an explicitly initialized module state."""
    global_initial = 0.0

    def evaluate(values: list[float]) -> float:
        y = [2.0 * values[0], 2.0 * values[1]]
        compute = y[0] * y[1]
        global_value = global_initial + compute
        z = [global_value]
        assert z == [24.0] if values == [3.0, 2.0] else len(z) == 1
        return compute

    values = [3.0, 2.0]
    direction = [0.1, -0.2]
    output = evaluate(values)
    jvp = _finite_difference(evaluate, values, direction)
    analytic = 4.0 * (direction[0] * values[1] + values[0] * direction[1])
    seed = 1.5
    vjp = [seed * 4.0 * values[1], seed * 4.0 * values[0]]
    assert output == 24.0 and math.isclose(jvp, analytic, rel_tol=2.0e-8)
    assert vjp == [12.0, 18.0]
    return {
        "status": "pass",
        "outputs": {"compute": output, "finite_difference_jvp": jvp, "global_after": 24.0},
        "vjp": {"x": vjp},
        "boundary": "the oracle initializes module global state explicitly and makes no exact-source global-mutation derivative claim",
    }


def lh142() -> dict[str, object]:
    """Check the affine allocated-vector map with explicit input contents."""
    initial = [3.0, 3.0, 3.0]
    inputs = [0.25, -0.5, 0.75]
    direction = [0.1, -0.2, 0.3]

    def evaluate(values: list[float]) -> float:
        outputs = [2.0 * (base + value) for base, value in zip(initial, values)]
        return sum(outputs)

    output = evaluate(inputs)
    jvp = _finite_difference(evaluate, inputs, direction)
    expected_jvp = 2.0 * sum(direction)
    assert math.isclose(output, 19.0, rel_tol=1.0e-12)
    assert math.isclose(jvp, expected_jvp, rel_tol=2.0e-8)
    return {
        "status": "pass",
        "outputs": {"sum_outputs": output, "finite_difference_jvp": jvp},
        "vjp": {"inputs_for_unit_sum_seed": [2.0, 2.0, 2.0]},
        "boundary": "allocated module inputs are undefined until supplied, and module-level mutable ownership is refused by FortAD",
    }


def vpf21() -> dict[str, object]:
    """Model overloaded derived-type subtraction and comparison."""
    values = [1.0, 4.0]
    direction = [0.2, -0.1]

    def evaluate(state: list[float]) -> float:
        return abs(state[0] - state[1])

    output = evaluate(values)
    jvp = _finite_difference(evaluate, values, direction)
    expected_jvp = direction[1] - direction[0]
    seed = 1.5
    vjp = [-seed, seed]
    assert output == 3.0 and math.isclose(jvp, expected_jvp, rel_tol=2.0e-8)
    assert vjp == [-1.5, 1.5]
    return {
        "status": "pass",
        "outputs": {"y": output, "finite_difference_jvp": jvp},
        "vjp": {"x": vjp},
        "boundary": "the independent scalar model covers the selected branch, while emitted derived-type procedures still need module context",
    }


ORACLES = {
    "v398-pointer-product": v398,
    "v529-global-state-product": v529,
    "lh142-allocated-affine-map": lh142,
    "vpf21-overloaded-derived-difference": vpf21,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = {args.case: ORACLES[args.case]()} if args.case else {name: fn() for name, fn in ORACLES.items()}
    print(json.dumps(selected, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
