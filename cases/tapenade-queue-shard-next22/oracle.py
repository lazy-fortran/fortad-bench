#!/usr/bin/env python3
"""Independent behavioral/refusal-boundary oracles for next22."""

from __future__ import annotations

import argparse
import json
import math


def lh123() -> dict[str, object]:
    """Bounded independent-iteration model with a finite-difference tangent."""
    def value(seed: float) -> float:
        a = [0.0, 1.0 + seed, 2.0, 3.0, 4.0, 5.0]
        b = [0.0, 1.5, 2.5, 3.5, 4.5, 5.5]
        total = a[5] * b[5]
        for n1, n2 in ((1, 2), (3, 4)):
            v1, v2, v3, v4 = a[n1], a[n2], b[n1], b[n2]
            if v3 > v4:
                v3 *= v4
            else:
                v4 /= v3
            u1 = (v1 - v2) ** 2 + (v3 - v4) ** 2
            u2 = abs(v1 * (v3 - v4) * (v2 + u1))
            update = math.sqrt(u1) * math.sqrt(u2)
            a[n1] += update
            a[n2] -= update
        return total + sum(b[i] * a[i] for i in range(1, 6))

    primal = value(0.0)
    tangent = (value(1.0e-6) - value(-1.0e-6)) / 2.0e-6
    assert math.isfinite(primal) and math.isfinite(tangent)
    assert abs(tangent) > 1.0e-3
    return {
        "status": "pass",
        "outputs": {"sumall": primal, "finite_difference_jvp": tangent},
        "boundary": "reverse branch inside an iteration loop requires control-flow reversal",
    }


def lh124() -> dict[str, object]:
    """Explicit bounded model of the localized-variable call boundary."""
    r = 1.0
    b = 0.1
    t = [0.0] * 32
    t[9], t[11] = 1.5, 2.0
    for i in range(10, 13):
        index = 2 * i - 3
        t[index] = b * (b + 1.0)
        r += (b * b) ** 2
        b = t[index] * t[index]
    t[10] = t[9] * t[11]
    assert math.isfinite(r) and math.isfinite(b)
    assert t[10] == 3.0 and t[9] == 1.5 and t[11] == 2.0
    return {
        "status": "pass",
        "outputs": {"r": r, "b": b, "t10": t[10]},
        "boundary": "same-file FFF call has no proven exact actual/formal mapping",
    }


def lh125() -> dict[str, object]:
    """Bounded trace with the implicit values made explicit."""
    tgh = 2.0
    h = 1.0
    teta7 = 1.4
    teta_after_loop = 1.4
    azim = teta7 / abs(teta7)
    hcrit = sum(tgh * abs(azim) for _ in range(4))
    acrit = hcrit * h
    output = acrit * teta_after_loop if acrit > 5.0 else 0.0
    jvp = 4.0 * h * abs(azim) * teta_after_loop
    seed = 1.25
    vjp_tgh = seed * jvp
    assert output == 11.2 and jvp == 5.6 and vjp_tgh == 7.0
    return {
        "status": "pass",
        "outputs": {"tetacrit": output, "jvp_tgh": jvp},
        "vjp": {"tgh": vjp_tgh},
        "boundary": "exact source leaves implicit and post-loop values undefined; reverse reports undeclared i",
    }


def lh126() -> dict[str, object]:
    """Initialized specialization of the conditional product map."""
    a, b = 2.0, 3.0
    da, db = 0.25, 0.5
    table = (0, 1, 0)
    i3 = 0
    for value in table:
        if value == 0:
            i3 = 7
    output = a * b if i3 > 0 else a
    jvp = da * b + a * db if i3 > 0 else da
    seed = 1.2
    a_bar = b * seed if i3 > 0 else seed
    b_bar = a * seed if i3 > 0 else 0.0
    assert output == 6.0 and jvp == 1.75
    assert math.isclose(a_bar, 3.6) and math.isclose(b_bar, 2.4)
    return {
        "status": "pass",
        "outputs": {"a": output, "jvp_a": jvp},
        "vjp": {"a": a_bar, "b": b_bar},
        "boundary": "exact loop bounds, table, and initial i3 are undefined; reverse needs an explicit dependent",
    }


ORACLES = {
    "lh123-independent-iterations": lh123,
    "lh124-localized-call": lh124,
    "lh125-implicit-state": lh125,
    "lh126-explicit-dependent": lh126,
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
