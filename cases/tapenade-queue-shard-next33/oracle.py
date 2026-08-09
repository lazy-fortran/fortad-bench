#!/usr/bin/env python3
"""Independent bounded behavior and refusal models for next33."""

from __future__ import annotations

import argparse
import json
import math


def _finite_difference(function, x: list[float], direction: list[float]) -> list[float]:
    eps = 1.0e-6
    plus = [a + eps * b for a, b in zip(x, direction)]
    minus = [a - eps * b for a, b in zip(x, direction)]
    return [(a - b) / (2.0 * eps) for a, b in zip(function(plus), function(minus))]


def _dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def _check_mvo02() -> dict[str, object]:
    def foo(x: list[float]) -> list[float]:
        y = x[0] * x[0]
        return [y * x[0]]

    x = [1.7]
    direction = [0.23]
    cotangent = [1.3]
    hand = [3.0 * x[0] * x[0] * direction[0]]
    finite = _finite_difference(foo, x, direction)
    adjoint = [3.0 * x[0] * x[0] * cotangent[0]]
    assert math.isclose(foo(x)[0], 1.7**3, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(hand[0], finite[0], rel_tol=0.0, abs_tol=2.0e-9)
    assert math.isclose(_dot(hand, cotangent), _dot(direction, adjoint), abs_tol=1.0e-12)
    return {
        "status": "pass",
        "primal": {"model": "same-file iface followed by cubic multiply", "value": foo(x)[0]},
        "derivative": {"status": "checked-independent", "jvp": hand[0], "vjp": adjoint[0]},
        "refusal": {"status": "expected", "boundary": "exact actual/formal mapping for direct same-file call"},
    }


def _check_v460() -> dict[str, object]:
    actual_shapes = {"r": [2], "s": [2]}
    specifics = {
        "compute1": {"first": [], "second": [2]},
        "compute2": {"first": [2], "second": [2]},
    }
    selected = [name for name, signature in specifics.items() if signature == {"first": actual_shapes["r"], "second": actual_shapes["s"]}]
    assert selected == ["compute2"]
    assert "ftest" not in {"compute1", "compute2"}
    return {
        "status": "pass",
        "primal": {
            "model": "rank-based generic dispatch with unresolved external result",
            "actual_shapes": actual_shapes,
            "selected_specific": selected[0],
            "external": "ftest",
        },
        "derivative": {"status": "not-claimed", "reason": "exact root reaches a local interface and an unresolved external function"},
        "refusal": {"status": "expected", "boundary": "local interface statement at line 12"},
    }


def _check_v031() -> dict[str, object]:
    def head(values: list[float]) -> list[float]:
        return [values[1], values[0], values[3], values[2]]

    values = [3.0, -2.0, 5.5, 7.25]
    direction = [0.2, -0.4, 0.7, 0.1]
    cotangent = [1.1, -0.3, 0.4, 0.8]
    hand = [direction[1], direction[0], direction[3], direction[2]]
    finite = _finite_difference(head, values, direction)
    adjoint = [cotangent[1], cotangent[0], cotangent[3], cotangent[2]]
    assert head(values) == [-2.0, 3.0, 7.25, 5.5]
    assert all(math.isclose(a, b, abs_tol=2.0e-9) for a, b in zip(hand, finite))
    assert math.isclose(_dot(hand, cotangent), _dot(direction, adjoint), abs_tol=1.0e-12)
    return {
        "status": "pass",
        "primal": {"model": "generic type-dispatched pair swap", "value": head(values)},
        "derivative": {"status": "checked-independent", "jvp": hand, "vjp": adjoint},
        "refusal": {"status": "expected", "boundary": "no derivative rule for generic swap"},
    }


def _check_v148() -> dict[str, object]:
    def order_zero(values: list[float]) -> list[float]:
        rho, ec, value, x = values
        new_rho = rho * value * ec + x
        return [new_rho, new_rho + value]

    values = [1.2, 2.0, 0.5, -0.25]
    direction = [0.1, -0.2, 0.3, 0.4]
    cotangent = [0.7, -0.6]
    rho, ec, value, _ = values
    drho, dec, dvalue, dx = direction
    dnew_rho = value * ec * drho + rho * value * dec + rho * ec * dvalue + dx
    hand = [dnew_rho, dnew_rho + dvalue]
    finite = _finite_difference(order_zero, values, direction)
    adjoint = [
        (value * ec) * cotangent[0] + (value * ec) * cotangent[1],
        (rho * value) * cotangent[0] + (rho * value) * cotangent[1],
        (rho * ec) * cotangent[0] + (rho * ec + 1.0) * cotangent[1],
        cotangent[0] + cotangent[1],
    ]
    assert all(math.isclose(a, b, abs_tol=2.0e-9) for a, b in zip(hand, finite))
    assert math.isclose(_dot(hand, cotangent), _dot(direction, adjoint), abs_tol=1.0e-12)
    return {
        "status": "pass",
        "primal": {"model": "defined order-zero optional map", "value": order_zero(values), "omitted_actuals": ["order", "value"]},
        "derivative": {"status": "checked-independent", "jvp": hand, "vjp": adjoint},
        "refusal": {"status": "expected", "boundary": "reverse dependent inference; exact test also omits optional actuals used by p"},
    }


CHECKS = {
    "mvo02-cubic-call": _check_mvo02,
    "v460-generic-interface": _check_v460,
    "v031-generic-swap": _check_v031,
    "v148-optional-map": _check_v148,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    selected = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in selected}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
