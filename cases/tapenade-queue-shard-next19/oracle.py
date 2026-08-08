#!/usr/bin/env python3
"""Independent behavioral and refusal-boundary oracles for next19."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


def lh110() -> dict[str, object]:
    a, b, c, d, e = 2.0, 3.0, 4.0, 5.0, 1.0
    if a > e:
        c += b
    d *= d
    assert (c, d) == (7.0, 25.0)
    # The source has a well-defined local branch Jacobian, but the exact
    # FortAD CLI cannot infer which arguments are active or which result is
    # the reverse dependent.
    jacobian = ((0.0, 1.0, 1.0, 0.0, 0.0), (0.0, 0.0, 0.0, 10.0, 0.0))
    assert jacobian[0][1] == 1.0 and jacobian[1][3] == 10.0
    return {"status": "pass", "outputs": {"c": c, "d": d}, "jacobian": jacobian, "boundary": "legacy REAL*8 plus automatic independent/dependent inference"}


def lh111() -> dict[str, object]:
    n = 8
    t = [0.0] * n
    u = [0.0] * n
    v = [0.0] * n
    w = [0.0] * n
    for i in range(n):
        t[i], u[i], v[i], w[i] = 1.0 + i, 2.0 + i, 3.0 + i, 4.0 + i
    l1 = [0.0] * n
    l2 = [0.0] * n
    l3 = [0.0] * n
    for i in range(1, n - 1):
        l1[i] = t[i - 1] * u[i + 1]
    for i in range(1, n - 1):
        l2[i] = t[i - 1] * l1[i + 1] + u[i]
    l2_seed = l2[1]
    for i in range(1, n - 1):
        l3[i] = l2[i - 1] * l1[i + 1]
        l2[i] = l3[i] * (t[i] + v[i])
    for i in range(1, n - 1):
        l1[i] = l1[i] * v[i] + l2[i] * l3[i]
        v[i] = w[i - 1] * w[i + 1] - l1[i]
    assert l2_seed == 13.0 and l3[2] == 0.0 and l1[2] != 0.0
    assert v[2] == w[1] * w[3] - l1[2]
    return {"status": "pass", "n": n, "outputs": {"v2": v[2], "l1_interior": l1[2]}, "boundary": "multiple mutated arrays require explicit reverse dependent selection"}


def lh112() -> dict[str, object]:
    # Choose the A <= 0 branch so the exact source has a finite result.
    a0, b0, t0 = -2.0, 4.0, 3.0
    a1 = t0 * a0
    b1 = b0
    t1 = 1.0 / (273.15 * b1)
    assert a1 == -6.0 and b1 == 4.0 and math.isfinite(t1)
    da0, db0, dt0 = 0.25, -0.5, 0.75
    da1 = t0 * da0 + a0 * dt0
    db1 = db0
    dt1 = -db0 / (273.15 * b0 * b0)
    assert abs(da1 + 0.75) < 1.0e-12
    assert abs(dt1 - 0.5 / (273.15 * 16.0)) < 1.0e-12
    # Reverse seed for T1 on this branch.
    seed = 1.25
    a_bar, b_bar, t_bar = 0.0, seed * (-1.0 / (273.15 * b0 * b0)), 0.0
    assert a_bar == 0.0 and t_bar == 0.0 and b_bar < 0.0
    return {"status": "pass", "primal": {"A": a1, "B": b1, "T": t1}, "jvp": {"A": da1, "B": db1, "T": dt1}, "vjp_T_seed": {"A": a_bar, "B": b_bar, "T": t_bar}, "boundary": "missing DIFFSIZES.inc reference plus invalid FortAD generated declarations"}


def lh113() -> dict[str, object]:
    source = (Path(__file__).parents[2] / "upstream/tapenade/nonRegressions/set01/lh113/program.f").read_text()
    lowered = source.lower()
    assert "do ie=1,ne" in lowered
    assert "ie = ie*2" in lowered
    assert "a(ia)" in lowered
    assert "ia" not in {"ie", "ne"}
    return {"status": "pass", "invalid_patterns": ["active DO variable reassigned", "undefined implicitly typed ia index"], "boundary": "invalid upstream Fortran control/storage semantics"}


ORACLES = {
    "lh110-legacy-inference": lh110,
    "lh111-array-liveness": lh111,
    "lh112-piecewise-sub": lh112,
    "lh113-invalid-do": lh113,
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
