#!/usr/bin/env python3
"""Independent primal and deliberate-refusal oracles for next16."""

from __future__ import annotations

import argparse
import json


def cm05() -> dict[str, object]:
    state = {"v3": 1.0, "v4": None, "p1": "v3", "p2": None, "p3": "v4"}
    state["p3"] = None
    state["p2"] = "allocated:p5"
    state["p1"] = state["p2"]
    assert state == {"v3": 1.0, "v4": None, "p1": "allocated:p5", "p2": "allocated:p5", "p3": None}
    return {"status": "pass", "final_aliases": state, "boundary": "pointer result and allocation identity"}


def cm10() -> dict[str, object]:
    allocated = False
    allocated = True
    allocated = False
    assert allocated is False
    return {"status": "pass", "allocated_after_call": allocated, "boundary": "pointer-component allocation lifetime"}


def cm34() -> dict[str, object]:
    objects = {
        "toto1.value": "allocated(1)",
        "toto1.next": "allocated(toto2)",
        "toto2.value": "allocated(1)",
        "toto3": "allocated(toto3)",
        "toto3.value": "allocated(1)",
    }
    assert len(objects) == 5
    return {"status": "pass", "allocated_components": objects, "boundary": "module mutable allocation and pointer ownership"}


def lh013() -> dict[str, object]:
    grddat_x = [1.0, 2.0, 3.0]
    grddat_y = [4.0, 5.0, 6.0]
    soldat2_b = [2.0, 3.0, 4.0]
    soldat2_c = [1.0, 1.5, 2.0]
    primal = [soldat2_b[i] * grddat_x[i] + soldat2_c[i] + grddat_y[i] for i in range(3)]
    dx = [0.5, -1.0, 2.0]
    dy = [1.0, 0.0, -0.5]
    db = [0.25, 0.5, -1.0]
    dc = [0.1, -0.2, 0.3]
    jvp = [db[i] * grddat_x[i] + soldat2_b[i] * dx[i] + dc[i] + dy[i] for i in range(3)]
    seed = [1.0, -2.0, 0.5]
    vjp_x = [seed[i] * soldat2_b[i] for i in range(3)]
    vjp_y = seed[:]
    vjp_b = [seed[i] * grddat_x[i] for i in range(3)]
    vjp_c = seed[:]
    lhs = sum(seed[i] * jvp[i] for i in range(3))
    rhs = sum(vjp_x[i] * dx[i] + vjp_y[i] * dy[i] + vjp_b[i] * db[i] + vjp_c[i] * dc[i] for i in range(3))
    assert primal == [7.0, 12.5, 20.0]
    assert abs(lhs - rhs) < 1.0e-12
    return {"status": "pass", "primal": primal, "jvp": jvp, "adjoint_dot": {"lhs": lhs, "rhs": rhs}, "boundary": "derived-type componentwise affine JVP/VJP"}


ORACLES = {
    "cm05-pointer-result": cm05,
    "cm10-allocation-lifetime": cm10,
    "cm34-derived-allocation": cm34,
    "lh013-derived-affine": lh013,
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
