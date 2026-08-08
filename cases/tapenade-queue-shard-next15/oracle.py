#!/usr/bin/env python3
"""Independent next15 behavioral and refusal-boundary oracles."""

from __future__ import annotations

import argparse
import json
import math


def v077() -> dict[str, object]:
    table = {
        f"{a},{b}": a or b for a in (False, True) for b in (False, True)
    }
    assert table == {
        "False,False": False,
        "False,True": True,
        "True,False": True,
        "True,True": True,
    }
    return {
        "status": "pass",
        "truth_table": table,
        "boundary": "logical primal only; numeric derivative storage is not claimed",
    }


def vpf20() -> dict[str, object]:
    x1, x2 = 1.0, 4.0
    nested = -x1
    result = -x2 + nested
    selected_input = -2.5
    selected = -selected_input
    assert result == -5.0 and selected == 2.5
    return {
        "status": "pass",
        "foo_result": result,
        "some_type2_minus_result": selected,
        "boundary": "active and dependent derived objects must name concrete REAL components",
    }


def lh230() -> dict[str, object]:
    a = 2.2
    tt1 = [10.0 + i for i in range(1, 31)]
    tt2 = [10.5 + i for i in range(1, 31)]
    b = a * a + tt2[4] * tt2[14]
    tt1[9] = a * a
    tt1[19] = math.sin(tt2[19])
    assert math.isclose(b, 400.09, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(tt1[9], 4.84, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(tt1[19], math.sin(30.5), rel_tol=0.0, abs_tol=1.0e-12)
    return {
        "status": "pass",
        "b": b,
        "pointer_write_10": tt1[9],
        "pointer_write_20": tt1[19],
        "boundary": "COMMON/SAVE pointer association storage identity",
    }


def lh232() -> dict[str, object]:
    a = 2.2
    tt1 = [10.0 + i for i in range(1, 31)]
    tt2 = [10.5 + i for i in range(1, 31)]
    a_after_foo = a * 3.3
    b_after_bar = a_after_foo * a_after_foo + tt2[4] * tt2[14]
    tt1[9] = a_after_foo * a_after_foo
    tt1[19] = math.sin(tt2[19])
    b = b_after_bar * a_after_foo
    assert math.isclose(b, 3252.172176, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(tt1[9], 52.7076, rel_tol=0.0, abs_tol=1.0e-12)
    return {
        "status": "pass",
        "b": b,
        "pointer_write_10": tt1[9],
        "pointer_write_20": tt1[19],
        "boundary": "COMMON/SAVE pointer association storage identity through an extra call",
    }


ORACLES = {
    "v077-logical-operator": v077,
    "vpf20-nested-derived": vpf20,
    "lh230-common-pointer": lh230,
    "lh232-common-pointer-call-tree": lh232,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = {args.case: ORACLES[args.case]()} if args.case else {
        name: fn() for name, fn in ORACLES.items()
    }
    print(json.dumps(selected, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
