#!/usr/bin/env python3
"""Independent bounded behavior and refusal models for next34.

The models do not read the Tapenade checkout, FortAD output, or exact source.
They check initialized allocation/global-state behavior separately from the
observed FortAD ownership and lifetime boundaries.
"""

from __future__ import annotations

import argparse
import json
import math


def _finite_difference(function, values: list[float], direction: list[float]) -> list[float]:
    step = 1.0e-6
    plus = [value + step * delta for value, delta in zip(values, direction)]
    minus = [value - step * delta for value, delta in zip(values, direction)]
    return [(a - b) / (2.0 * step) for a, b in zip(function(plus), function(minus))]


def _dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def _v235() -> dict[str, object]:
    """Evaluate a bounded saturation-state snapshot with initialized globals."""
    rr, vm, rhow, pc, tt = 8314.41, 18.01528, 997.0, 1200.0, 320.0
    w1, c1 = 0.5, 2.0
    tem = max(tt - 273.15, 25.0)
    tt1 = ((tem + 10.0) / 35.0) ** 2
    mt = (1.04 - tt1 / (24.0 + tt1)) * (647.3 - tt) / (647.3 - 298.15)
    mt = max(mt, 1.0e-4)
    relative_humidity = math.exp(-pc * vm / (rr * tt * rhow))
    saturation = 0.02 * relative_humidity ** (1.0 / mt)
    water_content = c1 * (w1 / c1) ** (1.0 / mt) * saturation
    assert all(math.isfinite(value) for value in (mt, relative_humidity, saturation, water_content))
    assert 0.0 < saturation < 0.02 and water_content > 0.0
    return {
        "status": "pass",
        "primal": {
            "model": "initialized saturation-state snapshot",
            "saturation": saturation,
            "water_content": water_content,
        },
        "state": {"updated_module_values": ["SS", "DSST", "DSSC", "WATCON"]},
        "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"},
        "derivative_claim": "none for exact module-owned state",
    }


def _module_allocation(case: str) -> dict[str, object]:
    """Model the initialized ten-element module allocation used by lh127/lh146."""
    a, b = 1.25, -3.0
    temporary = [a] * 10
    b += sum(temporary)
    allocated_after_return = False
    assert b == 9.5 and allocated_after_return is False
    return {
        "status": "pass",
        "primal": {
            "model": "allocate T(10), fill with A, add SUM(T), deallocate",
            "a": a,
            "b_after": b,
            "allocated_after_return": allocated_after_return,
        },
        "refusal": {"status": "expected", "boundary": "module-level allocatable T ownership"},
        "derivative_claim": "none for exact module-owned state",
        "case": case,
    }


def _lh134() -> dict[str, object]:
    """Check the bounded local allocation map and its explicit deallocation."""
    values = [1.2, 0.75]
    direction = [0.08, -0.13]
    cotangent = [0.7, -0.4]

    def mapping(state: list[float]) -> list[float]:
        x, y = state
        x_after = x * y
        temporary = [x_after * x_after] * 4
        y_after = (temporary[2] * temporary[3]) ** 2
        return [x_after, y_after]

    output = mapping(values)
    finite = _finite_difference(mapping, values, direction)
    x, y = values
    x_after = x * y
    analytical = [
        y * direction[0] + x * direction[1],
        8.0 * x_after**7 * (y * direction[0] + x * direction[1]),
    ]
    vjp = [
        cotangent[0] * y + cotangent[1] * 8.0 * x_after**7 * y,
        cotangent[0] * x + cotangent[1] * 8.0 * x_after**7 * x,
    ]
    assert all(math.isclose(a, b, abs_tol=2.0e-8) for a, b in zip(finite, analytical))
    assert math.isclose(_dot(analytical, cotangent), _dot(direction, vjp), abs_tol=1.0e-10)
    return {
        "status": "pass",
        "primal": {"model": "x=x*y; T(:)=x*x; y=T(3)*T(4); y=y*y", "output": output},
        "derivative": {"jvp": analytical, "finite_difference_jvp": finite, "vjp": vjp},
        "refusal": {"status": "expected", "boundary": "explicit deallocate of local allocatable T"},
        "derivative_claim": "bounded independent map only; no exact-source support claim",
    }


ORACLES = {
    "v235-saturation-state": _v235,
    "lh127-module-allocation": lambda: _module_allocation("lh127"),
    "lh134-local-allocation": _lh134,
    "lh146-module-allocation": lambda: _module_allocation("lh146"),
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
