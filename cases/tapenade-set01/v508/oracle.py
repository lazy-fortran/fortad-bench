#!/usr/bin/env python3
"""Independent numerical oracle for the defined v508 top-level map.

This does not invoke Fortran, Tapenade, or FortAD.  It models only the exact
observable semantics of compute/ftest/top: the scalar result, the in-place
array update, and the module-global accumulation.
"""

from __future__ import annotations

import math
import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v508" / "program.f90"


def observable(r: tuple[float, float], s: tuple[float, float], global_value: float) -> tuple[float, tuple[float, float], float]:
    del s
    updated_s = (2.0 * r[0], 2.0 * r[1])
    top = updated_s[0] * updated_s[1]
    return top, updated_s, global_value + top


def jvp(
    r: tuple[float, float],
    dr: tuple[float, float],
    ds: tuple[float, float],
    dglobal: float,
) -> tuple[float, tuple[float, float], float]:
    del ds
    top_d = 4.0 * (r[1] * dr[0] + r[0] * dr[1])
    return top_d, (2.0 * dr[0], 2.0 * dr[1]), dglobal + top_d


def top_vjp(r: tuple[float, float], cotangent: float) -> tuple[float, float]:
    return 4.0 * r[1] * cotangent, 4.0 * r[0] * cotangent


def main() -> None:
    source_text = SOURCE.read_text(encoding="utf-8")
    for pattern in (
        r"(?im)^\s*y\s*=\s*2\s*\*\s*x\s*$",
        r"(?im)^\s*compute\s*=\s*y\(1\)\s*\*\s*y\(2\)\s*$",
        r"(?im)^\s*global\s*=\s*global\s*\+\s*compute\s*$",
        r"(?im)^\s*top\s*=\s*ftest\(r\s*,\s*s\s*,\s*compute\s*\)\s*$",
    ):
        assert re.search(pattern, source_text), pattern

    r = (1.25, -0.75)
    s = (9.0, -4.0)
    global_value = 0.6
    dr = (0.3, -0.2)
    ds = (-0.8, 0.4)
    dglobal = 0.1
    cotangent = 0.7
    epsilon = 1.0e-6

    base = observable(r, s, global_value)
    plus = observable(
        (r[0] + epsilon * dr[0], r[1] + epsilon * dr[1]),
        (s[0] + epsilon * ds[0], s[1] + epsilon * ds[1]),
        global_value + epsilon * dglobal,
    )
    minus = observable(
        (r[0] - epsilon * dr[0], r[1] - epsilon * dr[1]),
        (s[0] - epsilon * ds[0], s[1] - epsilon * ds[1]),
        global_value - epsilon * dglobal,
    )
    finite_difference = (
        (plus[0] - minus[0]) / (2.0 * epsilon),
        tuple((high - low) / (2.0 * epsilon) for high, low in zip(plus[1], minus[1])),
        (plus[2] - minus[2]) / (2.0 * epsilon),
    )
    tangent = jvp(r, dr, ds, dglobal)
    finite_difference_error = max(
        abs(finite_difference[0] - tangent[0]),
        *(abs(high - low) for high, low in zip(finite_difference[1], tangent[1])),
        abs(finite_difference[2] - tangent[2]),
    )

    gradient = top_vjp(r, cotangent)
    adjoint_left = cotangent * tangent[0]
    adjoint_right = gradient[0] * dr[0] + gradient[1] * dr[1]
    adjoint_residual = abs(adjoint_left - adjoint_right)

    assert base[0] == 4.0 * r[0] * r[1]
    assert base[1] == (2.0 * r[0], 2.0 * r[1])
    assert base[2] == global_value + base[0]
    assert math.isfinite(finite_difference_error)
    assert math.isfinite(adjoint_residual)
    assert finite_difference_error < 1.0e-9, finite_difference_error
    assert adjoint_residual < 1.0e-12, adjoint_residual
    print(
        "oracle_status: pass "
        f"top={base[0]:.6g} "
        f"finite_difference_max_error={finite_difference_error:.3e} "
        f"adjoint_identity_residual={adjoint_residual:.3e} "
        "s_update=2*r global_update=global+top"
    )


if __name__ == "__main__":
    main()
