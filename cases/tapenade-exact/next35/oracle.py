#!/usr/bin/env python3
"""Independent bounded behavior and refusal models for next35.

These models do not read the Tapenade checkout, FortAD output, or generated
products. They check stateful primal behavior and numerical identities for the
two products that emitted FortAD sources, while recording no support claim for
the two refused exact roots.
"""

from __future__ import annotations

import argparse
import cmath
import json
import math


def _finite_difference(function, values: list[float], direction: list[float]) -> float:
    step = 1.0e-6
    plus = [value + step * delta for value, delta in zip(values, direction)]
    minus = [value - step * delta for value, delta in zip(values, direction)]
    return (function(plus) - function(minus)) / (2.0 * step)


def _dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def _v367() -> dict[str, object]:
    """Model foo's derived-state mutation and module-state writes."""
    first = {"a_t0_r": 1.5, "r": -2.0}
    second = {"a_t0_r": -0.75, "r": 4.0}
    g1 = first["a_t0_r"]
    g2 = second["a_t0_r"]
    first["a_t0_r"] = 0.0
    second["a_t0_r"] = 0.0
    assert g1 == 1.5 and g2 == -0.75
    assert first["a_t0_r"] == 0.0 and second["a_t0_r"] == 0.0
    return {
        "status": "pass",
        "primal": {
            "model": "foo reads two derived components into g1/g2 and zeros those components",
            "g1": g1,
            "g2": g2,
            "first_after": first,
            "second_after": second,
        },
        "refusal": {
            "status": "expected",
            "boundary": "module-level allocatable and mutable module state",
        },
        "derivative_claim": "none for exact module-owned state",
    }


def _v383() -> dict[str, object]:
    """Model multipl's saved allocatable state over two calls."""
    values = [1.0, 2.0, 3.0, 4.0, 5.0]
    nbrun: list[float] | None = None

    def multipl(x: list[float]) -> list[float]:
        nonlocal nbrun
        if nbrun is None:
            nbrun = [2.0] * 5
        output = [a * b for a, b in zip(x, nbrun)]
        nbrun = [a + 1.0 for a in nbrun]
        return output

    first = multipl(values)
    second = multipl(values)
    assert first == [2.0, 4.0, 6.0, 8.0, 10.0]
    assert second == [3.0, 6.0, 9.0, 12.0, 15.0]
    assert nbrun == [4.0] * 5
    return {
        "status": "pass",
        "primal": {
            "model": "saved allocatable nbrun starts at 2, scales x, then increments per call",
            "first_call": first,
            "second_call": second,
            "state_after": nbrun,
        },
        "refusal": {
            "status": "expected",
            "boundary": "unsupported .not. in an active expression; saved allocatable state is a later boundary",
        },
        "derivative_claim": "none for exact saved mutable state",
    }


def _lh050() -> dict[str, object]:
    """Check the real-coordinate map of sum_magnitude for complex doubles."""
    values = [1.2, -0.5, 0.75, 1.1]
    direction = [0.2, 0.3, -0.4, 0.15]
    cotangent = [1.7]

    def mapping(coords: list[float]) -> float:
        return sum(real * real + imag * imag for real, imag in zip(coords[::2], coords[1::2]))

    output = mapping(values)
    finite = _finite_difference(mapping, values, direction)
    hand = 2.0 * sum(value * delta for value, delta in zip(values, direction))
    vjp = [2.0 * value * cotangent[0] for value in values]
    assert math.isclose(output, 3.4625, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(hand, finite, rel_tol=0.0, abs_tol=2.0e-9)
    assert math.isclose(hand * cotangent[0], _dot(direction, vjp), rel_tol=0.0, abs_tol=1.0e-12)
    return {
        "status": "pass",
        "primal": {"model": "sum of squared real and imaginary coordinates", "value": output},
        "derivative": {
            "status": "checked-independent",
            "jvp": hand,
            "finite_difference_jvp": finite,
            "vjp": vjp,
        },
        "refusal": {"status": "not-applicable", "boundary": "none observed"},
    }


def _v046() -> dict[str, object]:
    """Check generic elemental integer/real dispatch and the real derivative."""
    x = 1.25
    i = 3

    def twice_real(value: float) -> float:
        return 2.0 * value

    def twice_int(value: int) -> int:
        return 2 * value

    def test(value: float, integer: int) -> float:
        return twice_real(value) + twice_int(integer)

    direction = 0.37
    finite = _finite_difference(lambda values: test(values[0], i), [x], [direction])
    hand = 2.0 * direction
    vjp = [2.0]
    assert twice_int(i) == 6
    assert math.isclose(twice_real(x), 2.5, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(test(x, i), 8.5, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(hand, finite, rel_tol=0.0, abs_tol=2.0e-9)
    assert math.isclose(hand, _dot([direction], vjp), rel_tol=0.0, abs_tol=1.0e-12)
    return {
        "status": "pass",
        "primal": {
            "model": "generic elemental twice(real)/twice(integer) dispatch",
            "real_twice": twice_real(x),
            "integer_twice": twice_int(i),
            "test": test(x, i),
        },
        "derivative": {
            "status": "checked-independent",
            "differentiated_input": "real x only",
            "jvp": hand,
            "finite_difference_jvp": finite,
            "vjp": vjp,
        },
        "refusal": {"status": "not-applicable", "boundary": "none observed"},
    }


ORACLES = {
    "v367-derived-state": _v367,
    "v383-saved-state": _v383,
    "lh050-complex-magnitude": _lh050,
    "v046-generic-elemental": _v046,
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
