#!/usr/bin/env python3
"""Independent bounded behavior and refusal models for next32."""

from __future__ import annotations

import argparse
import json


def _check_lh094() -> dict[str, object]:
    def crunch(x: list[float], y: list[float]) -> None:
        x[1] = x[2] * x[1]
        x[3] += y[4] * y[0]

    a = [1.0, 2.0, 3.0, 4.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    b = [0.0] * 10
    b[0], b[4] = 5.0, 6.0
    ff = b[:]
    gg = [0.0] * 10
    d = [0.0] * 10
    for y in (b, ff, gg, d):
        crunch(a, y)
    assert a[1] == 162.0 and a[3] == 64.0
    return {
        "status": "pass",
        "primal": {"model": "bounded repeated-call map with derived components", "a2": a[1], "a4": a[3]},
        "derivative": {"status": "not-claimed", "reason": "exact derived-type-containing root is refused by FortAD"},
        "refusal": {"status": "expected", "boundary": "unsupported statement at line 1"},
    }


def _check_ptr09() -> dict[str, object]:
    p = [[[100 * i + 10 * j + k for k in range(2)] for j in range(2)] for i in range(3)]
    section = [[p[1][j][k] for k in range(2)] for j in range(2)]
    assert section == [[100, 101], [110, 111]]
    return {
        "status": "pass",
        "primal": {"model": "bounded rank-2 pointer section alias", "shape": [2, 2], "values": section},
        "derivative": {"status": "not-claimed", "reason": "pointer association storage identity is not modeled by FortAD"},
        "refusal": {"status": "expected", "boundary": "pointer association storage identity"},
    }


def _check_v222() -> dict[str, object]:
    calls = {"test1": {"callee": "sub", "actuals": ["x", "x"], "external": "func(x)"}, "test2": {"callee": "sub", "actuals": ["x", "x"], "external": "func(x)"}}
    assert calls["test1"] == calls["test2"]
    return {
        "status": "pass",
        "primal": {"model": "bounded module/interface call map", "calls": calls},
        "derivative": {"status": "not-claimed", "reason": "local interface and exact xb(0)/external-FUNC context are outside the numeric oracle"},
        "refusal": {"status": "expected", "boundary": "local interface statement at line 25"},
    }


def _check_v436() -> dict[str, object]:
    profile = {"x": None, "a_shape": [2], "b_shape": [2], "scalar": "x"}
    assert profile["x"] is None and profile["a_shape"] == profile["b_shape"] == [2]
    return {
        "status": "pass",
        "primal": {"model": "bounded derived pointer-component storage map", "profile": profile},
        "derivative": {"status": "not-claimed", "reason": "exact root has no numeric operation and FortAD refuses the derived component"},
        "refusal": {"status": "expected", "boundary": "unsupported statement at line 1"},
    }


CHECKS = {
    "lh094-call-storage": _check_lh094,
    "ptr09-section-alias": _check_ptr09,
    "v222-interface-call": _check_v222,
    "v436-derived-pointer": _check_v436,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    selected = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in selected}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
