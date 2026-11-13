#!/usr/bin/env python3
"""Independent behavioral and refusal-boundary oracles for next21."""

from __future__ import annotations

import argparse
import json
import math


def lh119() -> dict[str, object]:
    # Model READ as a deterministic replacement for external input. This is
    # deliberately not a derivative claim for the exact active-I/O source.
    a = [1.0 + 0.02 * i for i in range(100)]
    b = [2.0 + 0.01 * i for i in range(100)]
    for i in range(4, 8):
        if a[i] > 0.0:
            a[i] *= b[i]
        b[i + 1] = (b[i] + b[i + 2]) / 2.0
    for j in range(6, 77, 3):
        b[j] = 0.25 + 0.01 * j
    b[9] *= a[9]
    a[9] *= b[9]
    assert math.isfinite(a[9]) and math.isfinite(b[9])
    return {
        "status": "pass",
        "outputs": {"a10": a[9], "b10": b[9]},
        "boundary": "active READ overwrites differentiated storage; unresolved TOTO is not modeled",
    }


def lh120() -> dict[str, object]:
    # The bounded scalar part of the labeled-GOTO recurrence is independent of
    # FortAD. The exact source additionally touches T(0,2) and later uses a
    # rank-mismatched T expression, so this does not claim exact-source safety.
    a1, a2 = 1.0, 2.0
    for i in range(1, 102):
        a1 *= 2.0
        if i <= 100:
            a2 += a1
    a2 *= a2
    assert a1 == 2.0**101
    assert a2 == a1**2
    return {
        "status": "pass",
        "bounded_recurrence": {"a1": a1, "a2": a2},
        "boundary": "fixed-form labeled GOTO plus unsafe/rank-mismatched array uses",
    }


def lh121() -> dict[str, object]:
    # Sentinel values make one outer and one inner iteration defined. The
    # local update is A(2)=A(1)^2, so its tangent and adjoint are explicit.
    t1 = [1, 0, 10, 0]
    a1 = 2.0
    a3 = 5.0
    a2 = a1 * a1
    da1 = 0.25
    da2 = 2.0 * a1 * da1
    seed = 1.5
    a1_bar = 2.0 * a1 * seed
    assert t1[0] > 0 and t1[2] >= 10
    assert a2 == 4.0 and da2 == 1.0 and a1_bar == 6.0
    assert a3 == 5.0
    return {
        "status": "pass",
        "outputs": {"a2": a2, "jvp_a2": da2},
        "vjp_a1": a1_bar,
        "boundary": "nested labeled DO WHILE requires construct-aware control-flow lowering",
    }


def lh122() -> dict[str, object]:
    # L64/L08/L01 applies A(10)=A(10)*A(11) once per covered element.
    maxwth = 3
    x, y = 2.0, 3.0
    dx, dy = 0.2, 0.4
    for _ in range(maxwth):
        x, dx = x * y, dx * y + x * dy
    assert x == 54.0 and abs(dx - 27.0) < 1.0e-12
    seed = 1.25
    x_bar = seed * y**maxwth
    y_bar = seed * maxwth * 2.0 * y ** (maxwth - 1)
    assert x_bar == 33.75 and y_bar == 67.5
    return {
        "status": "pass",
        "outputs": {"a10": x, "jvp_a10": dx},
        "vjp": {"a10": x_bar, "a11": y_bar},
        "boundary": "hierarchical legacy labeled DO control flow is refused before differentiation",
    }


ORACLES = {
    "lh119-active-io": lh119,
    "lh120-legacy-goto": lh120,
    "lh121-nested-do-while": lh121,
    "lh122-labeled-do": lh122,
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
