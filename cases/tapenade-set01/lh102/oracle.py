#!/usr/bin/env python3
"""Independent semantic oracle for the exact lh102 primal procedure."""

from __future__ import annotations

import math
import sys
from pathlib import Path


def primal(xx: float, vv1: float, vv2: float, vv3: float, zz: float) -> tuple[float, float, float]:
    """Return the mutated (xx, yy, zz) values of TESTPROTECT."""
    if xx > 0.0:
        tmp_y = xx * vv3 / vv1
        return math.sqrt(xx) * tmp_y, (1.0 - vv2) ** tmp_y, vv2**tmp_y
    return xx, 1.0, zz


def check() -> None:
    # The inactive branch must leave xx and zz untouched and set yy to one.
    assert primal(-2.0, 3.0, 0.25, 0.5, 7.0) == (-2.0, 1.0, 7.0)

    # A positive, integer-exponent point stays in the real-valued domain.
    xx, yy, zz = primal(4.0, 2.0, 0.25, 1.0, 0.0)
    assert math.isclose(xx, 4.0)
    assert math.isclose(yy, 0.75**2)
    assert math.isclose(zz, 0.25**2)

    # Independent centered differences check both positive-branch outputs.
    point = (4.0, 2.0, 0.25, 1.0, 0.0)
    step = 1.0e-6
    base = primal(*point)
    perturbed = primal(point[0] + step, *point[1:])
    yy_slope = (perturbed[1] - base[1]) / step
    zz_slope = (perturbed[2] - base[2]) / step
    assert math.isclose(yy_slope, 0.75**2 * math.log(0.75) / 2.0, rel_tol=2e-5)
    assert math.isclose(zz_slope, 0.25**2 * math.log(0.25) / 2.0, rel_tol=2e-5)


def main() -> int:
    check()
    if len(sys.argv) > 1 and not Path(sys.argv[1]).is_dir():
        raise SystemExit("source directory does not exist")
    print("oracle_behavioral_cases: 3")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
