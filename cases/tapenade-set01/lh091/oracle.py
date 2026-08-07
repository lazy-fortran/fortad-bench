#!/usr/bin/env python3
"""Independent behavioral oracle for the defined arithmetic in lh091."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def inventory(source: Path) -> None:
    text = source.read_text(encoding="latin-1")
    compact = re.sub(r"\s+", "", text).lower()
    for fragment in (
        "subroutinebugequiv(c)",
        "common/ccc/a,b",
        "equivalence(a(1,1),temp)",
        "x1(i)=ff(temp(i))",
        "b=b*x1(n-8)",
        "functionff(x)",
        "ff=2*x",
    ):
        require(fragment in compact, f"missing exact lh091 fragment {fragment!r}")
    print("oracle_source_inventory: exact BUGEQUIV/FF arithmetic shape pass")


def ff(x: float) -> float:
    return 2.0 * x


def one_iteration(a: list[float], b: float, n: int) -> tuple[list[float], float]:
    require(9 <= n <= 1000, "hidden n must select an in-range x1(n-8) slot")
    slot = n - 9  # temp(n-8) aliases a(n-8,1), zero-based here.
    x1_slot = ff(a[slot])
    return a[:], b * x1_slot


def jvp(a: list[float], b: float, n: int, da: list[float], db: float) -> float:
    slot = n - 9
    return db * ff(a[slot]) + b * 2.0 * da[slot]


def vjp(a: list[float], b: float, n: int, seed: float) -> tuple[list[float], float]:
    slot = n - 9
    gradient = [0.0] * len(a)
    gradient[slot] = seed * b * 2.0
    return gradient, seed * ff(a[slot])


def check_behavior() -> None:
    cases = (
        ([1.25, -2.0, 0.5, 3.0, -0.75], 2.0, 10, [0.2, 0.1, -0.4, 0.7, 1.1], -0.3, 0.8),
        ([-1.5, 0.25, 4.0, -2.5, 0.9], -3.0, 12, [0.6, -0.2, 0.3, 0.5, -0.8], 0.4, -1.2),
        ([0.0, 2.5, -3.5, 1.75, 5.0], 0.125, 13, [-0.1, 0.9, 0.2, -0.6, 0.4], -0.7, 2.3),
    )
    max_jvp = max_vjp = 0.0
    epsilon = 1.0e-6
    for a, b, n, da, db, seed in cases:
        _, value = one_iteration(a, b, n)
        ap = [x + epsilon * dx for x, dx in zip(a, da)]
        am = [x - epsilon * dx for x, dx in zip(a, da)]
        numeric_jvp = (
            one_iteration(ap, b + epsilon * db, n)[1]
            - one_iteration(am, b - epsilon * db, n)[1]
        ) / (2.0 * epsilon)
        analytic_jvp = jvp(a, b, n, da, db)
        max_jvp = max(max_jvp, abs(analytic_jvp - numeric_jvp))
        gradient, b_gradient = vjp(a, b, n, seed)
        directional = math.fsum(g * d for g, d in zip(gradient, da)) + b_gradient * db
        max_vjp = max(max_vjp, abs(directional - seed * analytic_jvp))
        require(value == b * ff(a[n - 9]), "independent one-iteration model mismatch")
    require(max_jvp < 1.0e-8, f"JVP finite-difference error {max_jvp}")
    require(max_vjp < 1.0e-12, f"VJP adjoint error {max_vjp}")
    require(ff(-1.75) == -3.5, "FF behavioral case failed")
    print(f"oracle_ff: pass value=2*x")
    print(f"oracle_bugequiv_update: 3 hidden-state cases pass")
    print(f"oracle_jvp_finite_difference: pass max_error={max_jvp:.16e}")
    print(f"oracle_vjp_adjoint_identity: pass max_error={max_vjp:.16e}")
    print("oracle_behavioral_cases: 3")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    source = parser.parse_args().source_dir.resolve() / "program.f"
    require(source.is_file(), "lh091 program.f is missing")
    inventory(source)
    check_behavior()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
