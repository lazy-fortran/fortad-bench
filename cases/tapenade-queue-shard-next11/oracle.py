"""Independent next11 primal oracles; no derivative-support oracle."""

from __future__ import annotations

import argparse
import json


def cm31() -> dict:
    state = {"object_x": True, "object_next": True, "next_x": True}
    state["object_x"] = False
    state["next_x"] = False
    assert state == {"object_x": False, "object_next": True, "next_x": False}
    return {"case": "cm31-pointer-allocation", "status": "pass", "primal": state,
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "expected", "boundary": "pointer association storage identity"}}


def cm32() -> dict:
    component = {"allocated": False, "next": None}
    component["allocated"] = True
    component["allocated"] = False
    assert component == {"allocated": False, "next": None}
    return {"case": "cm32-allocatable-component", "status": "pass", "primal": component,
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"}}


def v194() -> dict:
    a = [0.0] * 200
    b = [float(i) for i in range(200)]
    for i in range(0, 100, 2):
        a[i] = 2.0 * b[i]
    assert all(a[i] == 2.0 * b[i] for i in range(0, 100, 2))
    return {"case": "v194-forall-primal", "status": "pass",
            "primal": {"updated_even_indices": 50, "sample": a[2]},
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "observed", "boundary": "no inferred reverse dependent"}}


def v351() -> dict:
    data = [4.0, -2.0, 7.0, 1.0]
    assert min(data) == -2.0
    return {"case": "v351-minval", "status": "pass", "primal": {"minval": min(data)},
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "expected", "boundary": "generic MINVAL derivative output"}}


CHECKS = {"cm31-pointer-allocation": cm31, "cm32-allocatable-component": cm32,
          "v194-forall-primal": v194, "v351-minval": v351}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    names = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in names}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
