#!/usr/bin/env python3
"""Independent semantic oracle for the exact-source ht03 boundary."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def source_shape(source: Path) -> None:
    text = source.read_text(encoding="latin-1").lower()
    compact = re.sub(r"\s+", "", text)
    required = (
        "subroutinetop(i1,i2,i3,o1,o2,o3)",
        "callsub1(i1,i2,o1,o2)",
        "subroutinesub1(i1,i2,o1,o2)",
        "i2=i1-3*i2",
        "open(unit=3,file='toto')",
        "read(unit=3)o2",
        "o1=i1/o2",
    )
    missing = [fragment for fragment in required if fragment not in compact]
    if missing:
        raise SystemExit(f"ht03 source shape changed; missing {missing!r}")
    print("oracle_source_shape: top/sub1 call and external read inventory pass")


def model(i1: float, i2: float, i3: float, read_value: float) -> tuple[float, ...]:
    """Model top with the external READ result held fixed and nonzero."""
    if read_value == 0.0:
        raise ValueError("the conditional oracle requires a nonzero read value")
    final_i2 = i1 - 3.0 * i2
    o1 = (i1 / read_value) * read_value
    o2 = read_value
    o3 = i3 * i2
    return final_i2, o1, o2, o3


def jvp(
    i1: float, i2: float, i3: float, di1: float, di2: float, di3: float
) -> tuple[float, ...]:
    return di1 - 3.0 * di2, di1, 0.0, i2 * di3 + i3 * di2


def vjp(i2: float, i3: float, seeds: tuple[float, ...]) -> tuple[float, float, float]:
    bi2, bo1, _bo2, bo3 = seeds
    return bi2 + bo1, -3.0 * bi2 + i3 * bo3, i2 * bo3


def check_jvp() -> None:
    point = (1.7, -0.4, 2.3, 0.75)
    direction = (0.2, -0.3, 0.4)
    epsilon = 1.0e-6
    plus = model(
        point[0] + epsilon * direction[0],
        point[1] + epsilon * direction[1],
        point[2] + epsilon * direction[2],
        point[3],
    )
    minus = model(
        point[0] - epsilon * direction[0],
        point[1] - epsilon * direction[1],
        point[2] - epsilon * direction[2],
        point[3],
    )
    finite_difference = tuple(
        (a - b) / (2.0 * epsilon) for a, b in zip(plus, minus)
    )
    hand = jvp(*point[:3], *direction)
    if not all(
        math.isclose(a, b, rel_tol=2.0e-8, abs_tol=2.0e-9)
        for a, b in zip(hand, finite_difference)
    ):
        raise SystemExit(f"JVP finite-difference mismatch: hand={hand} fd={finite_difference}")
    print("oracle_jvp: conditional arithmetic model agrees with central differences")


def check_vjp() -> None:
    point = (1.7, -0.4, 2.3, 0.75)
    direction = (0.2, -0.3, 0.4)
    seeds = (1.1, -0.7, 0.9, 0.35)
    tangent = jvp(*point[:3], *direction)
    gradient = vjp(point[1], point[2], seeds)
    lhs = sum(seed * delta for seed, delta in zip(seeds, tangent))
    rhs = sum(component * delta for component, delta in zip(gradient, direction))
    if not math.isclose(lhs, rhs, rel_tol=1.0e-13, abs_tol=1.0e-13):
        raise SystemExit(f"VJP dot-product mismatch: lhs={lhs} rhs={rhs}")
    print("oracle_vjp: conditional Jacobian-transpose dot-product identity passes")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    source = args.source_root.resolve() / "program.f"
    if not source.is_file():
        raise SystemExit("ht03 exact source is missing")
    source_shape(source)
    check_jvp()
    check_vjp()
    print("oracle_domain: external READ result held fixed; no repaired port")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
