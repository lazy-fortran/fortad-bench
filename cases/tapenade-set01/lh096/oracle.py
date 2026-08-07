#!/usr/bin/env python3
"""Independent behavioral oracle for the exact lh096 liveness shape."""
from __future__ import annotations
import argparse
import math
import re
from pathlib import Path

def primal(a: float, b: float) -> tuple[float, float, float]:
    overwritten_b = 3.1 + math.log(a)
    d = 3.2 + 2.0 * overwritten_b**3
    return overwritten_b + d, overwritten_b, d

def jvp(a: float, da: float, b: float) -> tuple[float, float, float]:
    del b
    overwritten_b = 3.1 + math.log(a)
    db = da / a
    dd = 6.0 * overwritten_b**2 * db
    return db + dd, db, dd

def vjp(a: float, seeds: tuple[float, float, float]) -> tuple[float, float]:
    overwritten_b = 3.1 + math.log(a)
    da = (seeds[0] + seeds[1] + 6.0 * overwritten_b**2 * seeds[0] + 6.0 * overwritten_b**2 * seeds[2]) / a
    return da, 0.0

def check_source(source: Path) -> None:
    compact = re.sub(r"\s+", "", source.read_text(encoding="latin-1").lower())
    required = ("subroutinetestliveness(a,b,c,d)", "b=3.1+log(a)", "a=a*a", "d=3.2+sub1(a,b)", "a=b+d", "realfunctionsub1(a,b)", "a=2.0", "b=b*b*b", "sub1=a*b")
    missing = [item for item in required if item not in compact]
    if missing:
        raise SystemExit("lh096 source no longer matches exact liveness shape: " + ", ".join(missing))
    print("oracle_source: exact liveness operation inventory pass")

def check_behavior() -> None:
    cases = {"small": (0.7, -4.0), "unit": (1.0, 2.5), "large": (3.25, 9.0)}
    epsilon = 1.0e-6
    for name, (a, b) in cases.items():
        direction = 0.37
        tangent = jvp(a, direction, b)
        plus = primal(a + epsilon * direction, b)
        minus = primal(a - epsilon * direction, b)
        finite_difference = tuple((p - m) / (2.0 * epsilon) for p, m in zip(plus, minus))
        if not all(math.isclose(x, y, rel_tol=3e-6, abs_tol=3e-7) for x, y in zip(tangent, finite_difference)):
            raise SystemExit(f"JVP finite-difference mismatch for {name}: {tangent} vs {finite_difference}")
        seeds = (1.2, -0.4, 0.85)
        gradient = vjp(a, seeds)
        directional = sum(seed * value for seed, value in zip(seeds, tangent))
        if not math.isclose(gradient[0] * direction, directional, rel_tol=3e-6, abs_tol=3e-7):
            raise SystemExit(f"VJP adjoint mismatch for {name}: {gradient[0] * direction} vs {directional}")
        print(f"oracle_case: {name} final_state={primal(a, b)} jvp={tangent} vjp_dot={directional:.12g}")
    print("oracle_behavioral_cases: 3")
    print("oracle_status: pass")

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    check_source(parser.parse_args().source)
    check_behavior()
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
