#!/usr/bin/env python3
"""Independent numerical oracle for the set02/lh198 COMMON dataflow."""

from __future__ import annotations

import math
import sys
from pathlib import Path
from typing import Sequence


def source_inventory(source: Path) -> None:
    text = "".join(source.read_text(encoding="utf-8").lower().split())
    for fragment in (
        "subroutineaaa(x,y)",
        "subroutinebbb(x,y)",
        "subroutineccc(x,y)",
        "subroutineddd(x,y)",
        "common/comg/v3,v4",
        "common/comg/v5,v6",
        "callccc(x,y)",
    ):
        if fragment not in text:
            raise AssertionError(f"exact source is missing {fragment}")


def primal(x: float, y: float) -> float:
    """Return TOP's final y, preserving the aliased second /comG/ slot."""
    y = x + y  # AAA
    common_g_second = x  # BBB: v4 in /comG/
    y = x + y  # BBB
    y = y * common_g_second  # CCC
    y = x + y
    y = y * common_g_second  # internal DDD: v6 in /comG/
    return x + y


def jvp(x: float, y: float, xd: float, yd: float) -> float:
    common_g_second = x
    common_g_second_d = xd
    y1 = x + y
    y1_d = xd + yd
    y2 = x + y1
    y2_d = xd + y1_d
    y3 = y2 * common_g_second
    y3_d = y2_d * common_g_second + y2 * common_g_second_d
    y4 = x + y3
    y4_d = xd + y3_d
    y5 = y4 * common_g_second
    y5_d = y4_d * common_g_second + y4 * common_g_second_d
    del y1, y2, y3, y4, y5
    return xd + y5_d


def gradient(x: float, y: float) -> tuple[float, float]:
    return 1.0 + 2.0 * x + 6.0 * x * x + 2.0 * x * y, x * x


def run(source: Path) -> None:
    source_inventory(source)
    cases: tuple[tuple[float, float, float, float], ...] = (
        (1.5, 2.0, 0.13, -0.07),
        (-0.75, 1.2, -0.4, 0.6),
        (2.25, -0.8, 0.21, -0.31),
    )
    max_fd_error = 0.0
    max_adjoint_error = 0.0
    for x, y, xd, yd in cases:
        tangent = jvp(x, y, xd, yd)
        step = 1.0e-6
        finite_difference = (
            primal(x + step * xd, y + step * yd)
            - primal(x - step * xd, y - step * yd)
        ) / (2.0 * step)
        max_fd_error = max(max_fd_error, abs(tangent - finite_difference))

        seed = 0.73
        x_bar, y_bar = (seed * item for item in gradient(x, y))
        max_adjoint_error = max(
            max_adjoint_error,
            abs(x_bar * xd + y_bar * yd - seed * tangent),
        )
        if not math.isfinite(primal(x, y)):
            raise AssertionError("non-finite exact primal model")

    if max_fd_error > 2.0e-6 or max_adjoint_error > 2.0e-12:
        raise AssertionError(
            f"COMMON dataflow derivative mismatch: fd={max_fd_error} "
            f"adjoint={max_adjoint_error}"
        )
    print("oracle_semantics: top COMMON-block dataflow with /comG/ second slot aliased")
    print("oracle_behavioral_cases: 3")
    print(f"finite_difference_max_error: {max_fd_error:.6e}")
    print(f"adjoint_identity_max_error: {max_adjoint_error:.6e}")
    print(f"primal_reference_y: {primal(1.5, 2.0):.16e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    run(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).with_name("program.f"))
