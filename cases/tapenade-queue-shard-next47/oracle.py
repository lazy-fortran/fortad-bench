"""Independent bounded behavior/refusal models for next47."""

from __future__ import annotations

import argparse
import json
import math
from collections.abc import Callable


def _close(left: float, right: float) -> None:
    assert math.isclose(left, right, rel_tol=4.0e-5, abs_tol=4.0e-5), (left, right)


def _finite_difference(function: Callable[[float], float], value: float) -> float:
    step = 1.0e-6
    return (function(value + step) - function(value - step)) / (2.0 * step)


def _cm27() -> dict[str, object]:
    branches = []
    for b in (1.5, -0.75):
        target = "a" if b > 0.0 else "b"
        target_value = 1.0 if b > 0.0 else b
        branches.append({"b": b, "target": target, "target_value": target_value})
    assert branches == [
        {"b": 1.5, "target": "a", "target_value": 1.0},
        {"b": -0.75, "target": "b", "target_value": -0.75},
    ]
    return {
        "status": "pass",
        "behavior": {"branches": branches},
        "derivative": {"status": "not-defined-pointer-state-only"},
        "refusal": {
            "status": "expected",
            "boundary": "pointer association storage identity is not tracked",
        },
        "source_boundary": "the exact source changes p's target and does not define a numeric output map",
    }


def _cm28() -> dict[str, object]:
    value = 1.3
    direction = 0.27
    seed = -0.8
    function = lambda b: b * b
    primal = function(value)
    derivative = 2.0 * value
    finite = _finite_difference(function, value)
    _close(finite, derivative)
    jvp = derivative * direction
    vjp = derivative * seed
    _close(seed * jvp, direction * vjp)
    return {
        "status": "pass",
        "behavior": {"defined_branch": "b>0", "pointer_target": "b", "r": primal},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": finite * direction,
            "vjp": vjp,
            "adjoint_identity": seed * jvp,
        },
        "refusal": {
            "status": "expected",
            "boundary": "pointer association storage identity is not tracked",
        },
        "source_boundary": "b<=0 leaves p unassociated and is intentionally outside this bounded model",
    }


def _lh052() -> dict[str, object]:
    x, y, z = 0.7, -1.2, 2.5
    dx, dy, dz = 0.17, -0.23, 0.31
    xb, yb, zb = 1.2, -0.6, 0.4
    function = lambda left, right, fixed: (3.0 * left * left, 4.0 * right * right, fixed)
    primal = function(x, y, z)
    derivatives = (6.0 * x, 8.0 * y, 1.0)
    jvp = tuple(derivative * direction for derivative, direction in zip(derivatives, (dx, dy, dz)))
    finite = (
        _finite_difference(lambda value: function(value, y, z)[0], x),
        _finite_difference(lambda value: function(x, value, z)[1], y),
        1.0,
    )
    for expected, observed in zip(derivatives, finite):
        _close(expected, observed)
    vjp = tuple(derivative * seed for derivative, seed in zip(derivatives, (xb, yb, zb)))
    left = sum(seed * tangent for seed, tangent in zip((xb, yb, zb), jvp))
    right = sum(direction * adjoint for direction, adjoint in zip((dx, dy, dz), vjp))
    _close(left, right)
    return {
        "status": "pass",
        "behavior": {"outputs": {"x": primal[0], "y": primal[1], "z": primal[2]}},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": list(jvp),
            "finite_difference_components": list(finite),
            "vjp": list(vjp),
            "adjoint_identity": left,
        },
        "refusal": {
            "status": "expected",
            "boundary": "TARGET alias storage identity is not tracked",
        },
        "source_boundary": "the model preserves the two explicit target writes while the exact pointer alias graph remains unsupported",
    }


def _v118() -> dict[str, object]:
    def pointer_graph(p6_target: str | None) -> dict[str, str | None]:
        return {"p5_target": "v8", "p6_target": p6_target, "p7_target": p6_target}

    associated = pointer_graph("q")
    unassociated = pointer_graph(None)
    assert associated == {"p5_target": "v8", "p6_target": "q", "p7_target": "q"}
    assert unassociated == {"p5_target": "v8", "p6_target": None, "p7_target": None}
    return {
        "status": "pass",
        "behavior": {"p6_associated": associated, "p6_unassociated": unassociated},
        "derivative": {"status": "undefined-function-result-no-numeric-contract"},
        "refusal": {
            "status": "expected",
            "boundary": "pointer association storage identity is not tracked",
        },
        "source_boundary": "foo never assigns its function result; only pointer association state is modeled",
    }


ORACLES = {
    "cm27-pointer-branch": _cm27,
    "cm28-defined-pointer-branch": _cm28,
    "lh052-target-update": _lh052,
    "v118-pointer-graph": _v118,
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
