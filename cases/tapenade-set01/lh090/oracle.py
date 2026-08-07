#!/usr/bin/env python3
"""Independent semantic oracle for the exact-source lh090 boundary."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def finite_prefix(x0: float, steps: int) -> tuple[float, float]:
    """Return the final (x, y) after a finite prefix of the source loop."""
    x = x0
    y = 0.0
    for _ in range(steps):
        y = x * x
        x = y * 2.0
    return x, y


def finite_prefix_tangent(x0: float, dx0: float, steps: int) -> tuple[float, float, float, float]:
    x = x0
    xd = dx0
    y = 0.0
    yd = 0.0
    for _ in range(steps):
        yd = 2.0 * x * xd
        y = x * x
        xd = 2.0 * yd
        x = y * 2.0
    return x, y, xd, yd


def finite_prefix_reverse(x0: float, seeds: tuple[float, float], steps: int) -> tuple[float, float]:
    xs: list[float] = []
    x = x0
    for _ in range(steps):
        xs.append(x)
        x, _ = finite_prefix(x, 1)
    xb, yb = seeds
    for old_x in reversed(xs):
        yb = yb + 2.0 * xb
        xb = 2.0 * old_x * yb
        yb = 0.0
    return xb, yb


def check_control_flow(source: Path) -> None:
    text = source.read_text(encoding="latin-1").lower()
    compact = re.sub(r"\s+", "", text)
    required = ("subroutinetestinitadj(x,y)", "realx,y", "100y=x*x", "x=y*2", "if(y.gt.0.0)goto100")
    if any(fragment not in compact for fragment in required):
        raise SystemExit("lh090 source no longer matches the exact legacy-loop shape")
    for x0 in (0.25, 1.0, 3.0):
        x, y = finite_prefix(x0, 4)
        if not (x > 0.0 and y > 0.0):
            raise SystemExit("positive-prefix invariant failed")
    print("oracle_control_flow: positive-input branch repeats; no terminating execution")


def check_tangent() -> None:
    x0, dx0, steps, epsilon = 0.25, 0.7, 4, 1.0e-7
    x, y, tangent_x, tangent_y = finite_prefix_tangent(x0, dx0, steps)
    xp, yp = finite_prefix(x0 + epsilon * dx0, steps)
    xm, ym = finite_prefix(x0 - epsilon * dx0, steps)
    fd_x = (xp - xm) / (2.0 * epsilon)
    fd_y = (yp - ym) / (2.0 * epsilon)
    primal_x, primal_y = finite_prefix(x0, steps)
    if not math.isclose(x, primal_x, rel_tol=1e-13):
        raise SystemExit("tangent primal x mismatch")
    if not math.isclose(y, primal_y, rel_tol=1e-13):
        raise SystemExit("tangent primal y mismatch")
    if not math.isclose(tangent_x, fd_x, rel_tol=2e-5, abs_tol=2e-7):
        raise SystemExit(f"tangent x finite-difference mismatch: {tangent_x} vs {fd_x}")
    if not math.isclose(tangent_y, fd_y, rel_tol=2e-5, abs_tol=2e-7):
        raise SystemExit(f"tangent y finite-difference mismatch: {tangent_y} vs {fd_y}")
    print("oracle_tangent: finite-prefix recurrence agrees with central differences")


def check_reverse() -> None:
    x0, steps, seeds = 0.25, 4, (1.3, -0.4)
    gradient = finite_prefix_reverse(x0, seeds, steps)[0]
    epsilon = 1.0e-7
    xp = finite_prefix(x0 + epsilon, steps)
    xm = finite_prefix(x0 - epsilon, steps)
    fd = (seeds[0] * (xp[0] - xm[0]) + seeds[1] * (xp[1] - xm[1])) / (2.0 * epsilon)
    if not math.isclose(gradient, fd, rel_tol=2e-5, abs_tol=2e-7):
        raise SystemExit(f"reverse dot-product mismatch: {gradient} vs {fd}")
    if finite_prefix_reverse(x0, seeds, steps)[1] != 0.0:
        raise SystemExit("reverse overwritten y adjoint was not reset")
    print("oracle_reverse: finite-prefix reverse dot-product identity and y-adjoint reset pass")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    source = args.source_root.resolve() / "program.f"
    if not source.is_file():
        raise SystemExit("lh090 source is missing")
    check_control_flow(source)
    check_tangent()
    check_reverse()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
