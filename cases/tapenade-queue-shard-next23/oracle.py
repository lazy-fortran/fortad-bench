#!/usr/bin/env python3
"""Independent behavioral oracles for the next23 exact-source boundaries."""

from __future__ import annotations

import argparse
import json
import math


def _finite_difference(function, values: list[float], direction: list[float]) -> float:
    step = 1.0e-6
    plus = [value + step * delta for value, delta in zip(values, direction)]
    minus = [value - step * delta for value, delta in zip(values, direction)]
    return (function(plus) - function(minus)) / (2.0 * step)


def v035() -> dict[str, object]:
    """Snapshot the module parameters and evaluate the exact ffun arithmetic."""
    beta, mu0, par14 = 0.7, 2.0, 0.25
    l = 0.3
    x = [1.5, 0.2, -0.1, 0.4, -0.3, 2.2]
    u = [0.5, 0.7, 0.9]

    def evaluate(state: list[float]) -> list[float]:
        co, si = math.cos(l), math.sin(l)
        z = 1.0 + state[1] * co + state[2] * si
        h = state[3] * si - state[4] * co
        xx = 1.0 + state[3] ** 2 + state[4] ** 2
        q, s, w = u
        pmu0 = math.sqrt(state[0] / mu0)
        dt = 1.0 / (z**2 / state[0] / pmu0 + pmu0 / state[5] * h / z * w)
        fq = [0.0, si, -co, 0.0, 0.0]
        fs = [2.0 * state[0] / z, co + (state[1] + co) / z,
              si + (state[2] + si) / z, 0.0, 0.0]
        fw = [0.0, -h * state[2] / z, h * state[1] / z,
              xx / 2.0 * co / z, xx / 2.0 * si / z]
        result = [dt * pmu0 / state[5] * (fq[i] * q + fs[i] * s + fw[i] * w)
                  for i in range(5)]
        result.append(-dt * beta * math.sqrt(q**2 + s**2 + w**2 + par14))
        return result

    output = evaluate(x)
    direction = [0.1, -0.2, 0.15, 0.05, -0.1, 0.08]
    tangent = [_finite_difference(lambda state, i=i: evaluate(state)[i], x, direction)
               for i in range(6)]
    assert all(math.isfinite(value) for value in output + tangent)
    assert output[5] < 0.0 and max(abs(value) for value in tangent) > 1.0e-6
    return {
        "status": "pass",
        "outputs": {"f": output, "finite_difference_jvp": tangent},
        "boundary": "module-level allocatable SAVE state is outside the exact FortAD ownership contract",
    }


def cm35() -> dict[str, object]:
    """Model pointer-target rebinding with an explicit bounded loop count."""
    values = {"r1": 1.5, "r2": 2.0, "r3": 3.0}
    n = 1
    s1_target, s2_target, ps_target = "r1", "r3", "s1"
    for _ in range(0, n + 1):
        if ps_target == "s1":
            s1_target = "r2"
        else:
            s2_target = "r2"
        ps_target = "s2"
    result = 2.0 * values[s1_target] + values[s1_target] * values[s2_target]
    assert (s1_target, s2_target, ps_target) == ("r2", "r2", "s2")
    assert result == 2.0 * values["r2"] + values["r2"] ** 2 == 8.0
    return {
        "status": "pass",
        "outputs": {"result": result, "s1_target": s1_target, "s2_target": s2_target},
        "boundary": "the exact source leaves N undefined and uses TARGET/pointer storage identity",
    }


def cmv01() -> dict[str, object]:
    """Check the defined scalar map after supplying explicit pointer targets."""
    v2_value, v3_next_value = 2.0, 3.0
    dv2_value, dv3_next_value = 0.2, -0.1
    result = v2_value * v3_next_value
    jvp = dv2_value * v3_next_value + v2_value * dv3_next_value
    seed = 1.5
    v2_bar = seed * v3_next_value
    v3_next_bar = seed * v2_value
    assert result == 6.0 and math.isclose(jvp, 0.4)
    assert math.isclose(v2_bar, 4.5) and math.isclose(v3_next_bar, 3.0)
    return {
        "status": "pass",
        "outputs": {"result": result, "jvp": jvp, "v2_value_after": result},
        "vjp": {"v2_value": v2_bar, "v3_next_value": v3_next_bar},
        "boundary": "reverse has two active dependent candidates (v2 and r) until the dependent is explicit",
    }


def v307() -> dict[str, object]:
    """Check the selected-real-kind dnrm2 branch and its scalar derivative."""
    values = [-1.0, 2.0, -4.0]
    direction = [0.2, -0.1, 0.25]

    def dnrm2(state: list[float]) -> float:
        return max(0.0, abs(state[2]))

    output = dnrm2(values)
    jvp = _finite_difference(dnrm2, values, direction)
    seed = 1.5
    vjp = -seed
    assert output == 4.0 and math.isclose(jvp, -0.25, abs_tol=1.0e-8)
    assert vjp == -1.5
    return {
        "status": "pass",
        "outputs": {"dnrm2": output, "finite_difference_jvp": jvp},
        "vjp": {"x3": vjp},
        "boundary": "explicit finite input stays on the smooth negative-x(n) branch",
    }


ORACLES = {
    "v035-ffun-snapshot": v035,
    "cm35-bounded-pointer-trace": cm35,
    "cmv01-pointer-component-product": cmv01,
    "v307-dnrm2": v307,
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
