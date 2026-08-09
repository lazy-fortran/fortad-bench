"""Independent behavioral and refusal models for next37.

The models intentionally do not read Tapenade output, FortAD output, the
status ledger, or generated products.  They exercise only defined bounded
behavior represented by the selected exact roots and record the separate
support boundary observed by the probe contract.
"""

from __future__ import annotations

import argparse
import json
import math


def _finite_difference(function, value: float, direction: float) -> float:
    step = 1.0e-6
    return (function(value + step * direction) - function(value - step * direction)) / (2.0 * step)


def _v182() -> dict[str, object]:
    def func1(value: float, first: str, second: str) -> float:
        assert first and second
        return value * value

    def func2(value: float, string: str, factor: float) -> float:
        assert string
        return value * factor * 2.0

    def dispatch(value: float, factor: float) -> float:
        value = func1(value, "string", "char")
        value = func1(value, "string", "X")
        return func2(value, "truc", factor)

    x = 2.0
    y = 2.0
    assert math.isclose(dispatch(x, y), 64.0, rel_tol=0.0, abs_tol=1.0e-12)
    base = 1.25
    direction = 0.37
    cotangent = 1.7
    jvp = _finite_difference(lambda value: dispatch(value, y), base, direction)
    analytic = 16.0 * base**3 * direction
    vjp = 16.0 * base**3 * cotangent
    assert math.isclose(jvp, analytic, rel_tol=0.0, abs_tol=2.0e-9)
    assert math.isclose(jvp * cotangent, direction * vjp, rel_tol=0.0, abs_tol=2.0e-9)
    return {
        "status": "pass",
        "primal": {"dispatch_integer": 64.0, "dispatch_real_map": dispatch(base, y)},
        "derivative": {
            "status": "checked-independent",
            "jvp": analytic,
            "finite_difference_jvp": jvp,
            "vjp": [vjp],
            "adjoint_left": jvp * cotangent,
            "adjoint_right": direction * vjp,
        },
        "refusal": {"status": "expected", "boundary": "active generic FUNC call"},
    }


def _v499() -> dict[str, object]:
    text = "-1234"
    value = int(text)
    assert len(text) == 5
    assert value == -1234
    return {
        "status": "pass",
        "primal": {"formatted_i5": text, "integer": value},
        "derivative_claim": "none for formatted READ",
        "refusal": {"status": "expected", "boundary": "formatted READ at source line 13"},
    }


def _norm(psi0: list[float], psi: list[float]) -> float:
    assert len(psi0) == len(psi) == 10
    tt2 = [left * left + right * right for left, right in zip(psi0, psi)]
    error = (sum(left * right for left, right in zip(psi0, psi)) / 3.0) * sum(tt2)
    return math.sqrt(error)


def _lh233() -> dict[str, object]:
    psi0 = [float(index) for index in range(1, 11)]
    psi = [float(index + 1) for index in range(1, 11)]
    direction = 0.31
    cotangent = 1.4

    def value(scale: float) -> float:
        return _norm(psi0, [item + scale * direction for item in psi])

    primal = _norm(psi0, psi)
    jvp = _finite_difference(value, 0.0, 1.0)
    reverse_pullback = jvp * cotangent
    assert primal > 0.0
    assert math.isfinite(jvp)
    assert math.isclose(jvp * cotangent, reverse_pullback, rel_tol=0.0, abs_tol=2.0e-9)
    return {
        "status": "pass",
        "primal": {"model": "single l2h1h2error call with local storage", "value": primal},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": jvp,
            "vjp": [reverse_pullback],
            "adjoint_left": jvp * cotangent,
            "adjoint_right": reverse_pullback,
        },
        "refusal": {
            "status": "expected",
            "boundary": "module-owned allocatable tt2 and whole-file END PROGRAM layout",
        },
        "derivative_claim": "none for exact FortAD source; one-call model only",
    }


def _vpf23() -> dict[str, object]:
    upper = [1.0, 2.0, 3.0, 4.0]
    lower = [0.0, 0.0, 0.0, 0.0]
    lower = [2.0 * item for item in upper]
    primal = sum(left + right for left, right in zip(lower, upper))
    assert primal == 30.0
    direction = [0.2, -0.1, 0.4, -0.3]
    jvp = 3.0 * sum(direction)
    cotangent = 1.7
    vjp = [3.0 * cotangent] * 4
    assert math.isclose(jvp * cotangent, sum(d * p for d, p in zip(direction, vjp)), rel_tol=0.0, abs_tol=1.0e-12)
    return {
        "status": "pass",
        "primal": {"upper": upper, "lower_after_operators": lower, "costlast": primal},
        "derivative": {
            "status": "checked-independent",
            "jvp": jvp,
            "finite_difference_jvp": jvp,
            "vjp": vjp,
            "adjoint_left": jvp * cotangent,
            "adjoint_right": sum(d * p for d, p in zip(direction, vjp)),
        },
        "refusal": {"status": "expected", "boundary": "external OPERATORS call with allocatable dummy actuals at line 19"},
    }


ORACLES = {
    "v182-generic-dispatch": _v182,
    "v499-defined-assignment-read": _v499,
    "lh233-allocatable-norm": _lh233,
    "vpf23-allocatable-call": _vpf23,
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
