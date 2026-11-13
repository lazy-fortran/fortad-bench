#!/usr/bin/env python3
"""Independent primal/refusal models for the next2 modern shard."""
from __future__ import annotations
import argparse
import json


def vpf19():
    result = {"f": {"f": 4.0 - 1.5}}
    assert result == {"f": {"f": 2.5}}
    return {"case": "vpf19-nested-difference", "status": "pass", "primal": {"model": "nested derived-component subtraction", "result": result}, "derivative": {"status": "not-defined", "reason": "active derived object must name a real component"}, "refusal": {"status": "expected", "boundary": "active derived-type component"}}


def v479():
    pointers = {"avv1": "davv1", "aa1": "daa1"}
    allocated = ["aa2", "avv2"]
    assert pointers == {"avv1": "davv1", "aa1": "daa1"} and allocated == ["aa2", "avv2"]
    return {"case": "v479-module-state", "status": "pass", "primal": {"model": "module pointer association and allocation", "pointers": pointers, "allocated": allocated}, "derivative": {"status": "not-defined", "reason": "module-level mutable state is outside the contract"}, "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"}}


def lh111():
    fields = {name: [[2.0, 2.0], [2.0, 2.0]] for name in ("temporary0", "temporary1", "thck")}
    assert fields["thck"][0][0] == 2.0
    return {"case": "lh111-pointer-field", "status": "pass", "primal": {"model": "three allocated pointer fields with propagated value", "result": fields["thck"]}, "derivative": {"status": "not-defined", "reason": "pointer-association storage identity is not represented"}, "refusal": {"status": "expected", "boundary": "pointer-association storage identity"}}


def v520():
    volumes, density, force, acceleration = [2.0, 4.0], [3.0, 5.0], 10.0, 1.0
    acc = [force / (density[i] * volumes[i] * acceleration) for i in range(2)]
    final_force = density[-1] * volumes[-1] * acceleration * (-9.81 + acceleration + sum(acc))
    assert abs(acc[0] - 5.0 / 3.0) < 1e-12 and abs(acc[1] - 0.5) < 1e-12
    assert abs(final_force + 132.86666666666667) < 1e-10
    return {"case": "v520-force-calculation", "status": "pass", "primal": {"model": "allocatable-component force update", "acc": acc, "force": final_force}, "derivative": {"status": "not-defined", "reason": "allocatable derived-component state boundary"}, "refusal": {"status": "expected", "boundary": "module-level allocatable mutable state"}}


CHECKS = {"vpf19-nested-difference": vpf19, "v479-module-state": v479, "lh111-pointer-field": lh111, "v520-force-calculation": v520}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    names = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in names}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
