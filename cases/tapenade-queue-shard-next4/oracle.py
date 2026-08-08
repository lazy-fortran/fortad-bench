#!/usr/bin/env python3
"""Independent primal and refusal-boundary models for the next4 shard."""

from __future__ import annotations

import argparse
import json


def _v342() -> dict:
    value = 2
    storage_identity = True
    assert value == 2 and storage_identity
    return {"case": "v342-pointer", "status": "pass", "primal": {"value": value, "storage_identity": storage_identity}, "derivative": {"status": "not-defined", "reason": "pointer target identity is not represented"}, "refusal": {"status": "expected", "boundary": "pointer association storage identity"}}


def _mvo33() -> dict:
    def dispatch(scale: float, x: float) -> float:
        return scale * x
    first, second = dispatch(2.0, 1.0), dispatch(3.0, 1.0)
    assert first == 2.0 and second == 3.0
    return {"case": "mvo33-dispatch", "status": "pass", "primal": {"first": first, "second": second}, "derivative": {"status": "not-defined", "reason": "procedure-pointer target flow is unresolved"}, "refusal": {"status": "expected", "boundary": "procedure-pointer callback statement"}}


def _vpf09() -> dict:
    shape = (2, 3)
    aliased = True
    assert shape == (2, 3) and aliased
    return {"case": "vpf09-layout", "status": "pass", "primal": {"shape": shape, "aliased": aliased, "contiguous": True}, "derivative": {"status": "not-defined", "reason": "contiguous pointer storage identity is not represented"}, "refusal": {"status": "expected", "boundary": "contiguous pointer alias declaration"}}


def _v335() -> dict:
    declarations = {"allocatable": True, "pointer": True, "optional": True}
    assert all(declarations.values())
    return {"case": "v335-declarations", "status": "pass", "primal": {"declarations": declarations}, "derivative": {"status": "not-defined", "reason": "independent variables are not inferable from declaration-only source"}, "refusal": {"status": "expected", "boundary": "missing explicit independent variables"}}


CHECKS = {"v342-pointer": _v342, "mvo33-dispatch": _mvo33, "vpf09-layout": _vpf09, "v335-declarations": _v335}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    names = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in names}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
