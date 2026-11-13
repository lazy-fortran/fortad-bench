"""Independent primal models for next10; no derivative-support oracle."""

from __future__ import annotations

import argparse
import json
import math


def v285() -> dict:
    state = {"nvariable": 3, "nface": 2, "allocatable_arrays": 12, "call_reached": True}
    assert state["call_reached"] and state["allocatable_arrays"] > 0
    return {"case": "v285-module-state", "status": "pass", "primal": state,
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"}}


def lh176() -> dict:
    f = [0.0] * 11
    face_to_node = list(range(1, 11))
    source = 2.5
    for _ in range(10):
        for index in face_to_node:
            f[index] = source
    assert f[1:] == [source] * 10 and f[0] == 0.0
    return {"case": "lh176-pointer-write", "status": "pass",
            "primal": {"updated_nodes": 10, "value": source},
            "derivative": {"status": "not-claimed"},
            "refusal": {"status": "expected", "boundary": "pointer association storage identity"}}


def tree(include_assignment: bool) -> dict:
    t1, lpos, pos = 2.0, 3.0, 0.5
    before = t1 * lpos * pos
    after = before * before
    assert math.isclose(after, 9.0)
    result = {"case": "cmv03-tree-assignment" if include_assignment else "cmv02-tree-arithmetic",
              "status": "pass", "primal": {"pos_before": before, "pos_after": after},
              "derivative": {"status": "not-claimed"}}
    if include_assignment:
        result["primal"]["pointer_assignment"] = "t2.sons.tree -> t1.sons.tree"
    return result


CHECKS = {"v285-module-state": v285, "lh176-pointer-write": lh176,
          "cmv02-tree-arithmetic": lambda: tree(False),
          "cmv03-tree-assignment": lambda: tree(True)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    names = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in names}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
