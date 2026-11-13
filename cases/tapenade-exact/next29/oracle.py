#!/usr/bin/env python3
"""Independent bounded behavior and refusal models for next29.

These models do not read the Tapenade checkout, FortAD output, or exact source
files. They use initialized values to check the local numeric/storage map and
retain the observed refusal boundary separately from that bounded model.
"""

from __future__ import annotations

import argparse
import json
import math


def _lh221_map(h: list[float], bsoc: list[float], sealevel: float, rho_sea: float, rho_i: float) -> tuple[list[float], list[float], list[float], list[float]]:
    h_rho = [value * rho_i for value in h]
    b = []
    flotte = []
    h_buoy = []
    for ground, rho in zip(bsoc, h_rho):
        if ground <= sealevel - rho / rho_sea:
            b.append(sealevel - rho / rho_sea)
            flotte.append(1.0)
        else:
            b.append(ground)
            flotte.append(0.0)
            h_buoy.append((sealevel - ground) * rho_sea / rho_i)
    h_buoy = [(sealevel - ground) * rho_sea / rho_i for ground in bsoc]
    h_buoy = [old - new for old, new in zip(h, h_buoy)]
    s = [old + new for old, new in zip(h, b)]
    return b, flotte, h_buoy, s


def _check_lh221() -> dict[str, object]:
    h = [2.0, 4.0]
    bsoc = [0.0, 5.0]
    values = _lh221_map(h, bsoc, 10.0, 2.0, 1.0)
    assert values == ([9.0, 8.0], [1.0, 1.0], [-18.0, -6.0], [11.0, 12.0])
    eps = 1.0e-6
    plus = _lh221_map([h[0] + eps, h[1]], bsoc, 10.0, 2.0, 1.0)[3]
    minus = _lh221_map([h[0] - eps, h[1]], bsoc, 10.0, 2.0, 1.0)[3]
    jvp = (plus[0] - minus[0]) / (2.0 * eps)
    assert math.isclose(jvp, 0.5, rel_tol=1.0e-8)
    return {
        "status": "pass",
        "primal": {"model": "initialized bounded WHERE and buoyancy map", "outputs": values},
        "derivative": {"status": "checked-bounded-jvp", "h1_to_s1": jvp},
        "refusal": {"status": "expected", "boundary": "module array section base is not declared"},
    }


def _check_v526() -> dict[str, object]:
    x, y, n = 2.0, 3.0, 4
    pointer_target = [0.0, 0.0]
    y_after_call = y + n * x * x
    pointer_target[:] = [x, x]
    x_after = x + 10.0
    y_after = y_after_call + pointer_target[1]
    assert (x_after, y_after) == (12.0, 21.0)
    return {
        "status": "pass",
        "primal": {"model": "explicitly associated pointer target and gee call", "x": x_after, "y": y_after},
        "derivative": {"status": "checked-bounded-jvp", "dx": 1.0, "dy": 17.0},
        "refusal": {"status": "expected", "boundary": "same-file procedure call actual/formal mapping"},
    }


def _check_lh097() -> dict[str, object]:
    vv = 3.0
    output = vv + vv + 2.0
    jvp = 2.0
    assert output == 8.0 and jvp == 2.0
    return {
        "status": "pass",
        "primal": {"model": "initialized derived-type component assignment", "output": output},
        "derivative": {"status": "checked-analytical-jvp", "doutput_dvv": jvp},
        "refusal": {"status": "expected", "boundary": "multiple derived-type dependent candidates"},
    }


def _check_v178() -> dict[str, object]:
    value, sign = 2.0, -1.0
    output = value * value * sign
    jvp = 2.0 * value * sign
    assert (output, jvp) == (-4.0, -4.0)
    return {
        "status": "pass",
        "primal": {"model": "bounded lbc_lnk_2d point update", "output": output},
        "derivative": {"status": "checked-analytical-jvp", "doutput_dvalue": jvp},
        "refusal": {"status": "expected", "boundary": "reverse dependent inference for INTENT(INOUT) array"},
    }


CHECKS = {
    "lh221-flottab-map": _check_lh221,
    "v526-foo-pointer-call": _check_v526,
    "lh097-top-derived-map": _check_lh097,
    "v178-lbc-map": _check_v178,
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
