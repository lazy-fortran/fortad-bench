#!/usr/bin/env python3
"""Independent primal models and refusal-boundary checks for next5."""
from __future__ import annotations
import argparse, json

def v540a():
    x, y = [1.0, 0.5, 1.0, 0.25], [0.5, 1 / 3, 0.25, 0.2, 1 / 6]
    z = [x[2] * (i - 1) for i in range(1, 8)]
    pp = [x[0] * y[1], x[1] * y[2], x[2] * y[3], x[3] * y[4]]
    value = x[2] * y[1] + sum(pp) + z[-1]
    assert len(z) == 7 and len(pp) == 4 and value > 0
    return {"case": "v540a-allocations", "status": "pass", "primal": {"allocated_z": len(z), "allocated_pp": len(pp), "value": value}, "derivative": {"status": "not-defined", "reason": "TARGET alias storage identity is not represented"}, "refusal": {"status": "expected", "boundary": "allocatable TARGET alias declaration"}}

def v541a():
    x, y = [1.0, 0.5, 1.0, 0.25], [0.5, 1 / 3, 0.25, 0.2, 1 / 6]
    z = [x[2] * (i - 1) for i in range(1, 8)]
    pp = [(i - 1) * y[(i - 1) // 2] for i in range(1, 11)]
    value = x[2] * y[1] + sum(pp) + z[-1]
    assert len(z) == 7 and len(pp) == 10 and value > 0
    return {"case": "v541a-allocations", "status": "pass", "primal": {"allocated_z": len(z), "allocated_pp": len(pp), "value": value}, "derivative": {"status": "not-defined", "reason": "TARGET alias storage identity is not represented"}, "refusal": {"status": "expected", "boundary": "allocatable TARGET alias declaration"}}

def v339():
    node = {"val": 2.0, "next": {"val": 3.0, "next": None}}
    current = node
    pointer_alias = current["next"]
    value = node["val"] ** 2
    current = node
    assert pointer_alias is node["next"] and value == 4.0
    return {"case": "v339-linked-pointer", "status": "pass", "primal": {"value": value, "alias_preserved": pointer_alias is node["next"]}, "derivative": {"status": "not-defined", "reason": "pointer association storage identity is not represented"}, "refusal": {"status": "expected", "boundary": "pointer association alias declaration"}}

def v197():
    q = [[[[1.0 for _ in range(5)] for _ in range(5)] for _ in range(5)] for _ in range(5)]
    s = 0.0
    for i in range(5):
        for j in range(5):
            for k in range(5):
                s += sum(q[i][j][k][d] ** 2 for d in range(5))
    assert s == 625.0
    return {"case": "v197-block", "status": "pass", "primal": {"q_shape": [5, 5, 5, 5], "sum_squares": s}, "derivative": {"status": "not-defined", "reason": "rank-greater-than-two array section is outside the supported boundary"}, "refusal": {"status": "expected", "boundary": "rank-greater-than-two array section"}}

CHECKS = {"v197-block": v197, "v339-linked-pointer": v339, "v540a-allocations": v540a, "v541a-allocations": v541a}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    names = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in names}, sort_keys=True))
    return 0

if __name__ == "__main__": raise SystemExit(main())
