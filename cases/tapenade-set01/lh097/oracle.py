#!/usr/bin/env python3
"""Independent fixed-read-value semantic oracle for exact lh097."""
from __future__ import annotations
import argparse
import math
import re
from pathlib import Path

def primal(a: float, read_value: float) -> tuple[float, float]:
    b = a * a
    return b, read_value * b

def jvp(a: float, da: float, read_value: float) -> tuple[float, float]:
    db = 2.0 * a * da
    return db, read_value * db

def vjp(a: float, seeds: tuple[float, float], read_value: float) -> float:
    return 2.0 * a * (seeds[0] + read_value * seeds[1])

def check_source(source: Path) -> None:
    compact = re.sub(r"\s+", "", source.read_text(encoding="latin-1").lower())
    required = ("subroutinetestiotbr(a,b,c)", "b=a*a", "read(12,*),a", "c=a*b")
    if any(fragment not in compact for fragment in required):
        raise SystemExit("lh097 source no longer matches the exact I/O-overwrite shape")
    print("oracle_source: exact I/O-overwrite operation inventory pass")

def check_tangent() -> None:
    a, da, read_value, epsilon = 1.25, -0.6, 2.75, 1.0e-7
    tangent = jvp(a, da, read_value)
    plus, minus = primal(a + epsilon * da, read_value), primal(a - epsilon * da, read_value)
    finite_difference = tuple((p - m) / (2.0 * epsilon) for p, m in zip(plus, minus))
    if not all(math.isclose(x, y, rel_tol=2e-6, abs_tol=2e-7) for x, y in zip(tangent, finite_difference)):
        raise SystemExit(f"JVP finite-difference mismatch: {tangent} vs {finite_difference}")
    print("oracle_tangent: fixed-read-value JVP agrees with central differences")

def check_reverse() -> None:
    a, read_value, seeds, epsilon = -0.8, 1.5, (0.7, -1.2), 1.0e-7
    gradient = vjp(a, seeds, read_value)
    plus, minus = primal(a + epsilon, read_value), primal(a - epsilon, read_value)
    directional = sum(seed * (p - m) / (2.0 * epsilon) for seed, p, m in zip(seeds, plus, minus))
    if not math.isclose(gradient, directional, rel_tol=2e-6, abs_tol=2e-7):
        raise SystemExit(f"VJP adjoint mismatch: {gradient} vs {directional}")
    print("oracle_reverse: fixed-read-value VJP passes the adjoint identity")

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    source = parser.parse_args().source_root.resolve() / "program.f"
    if not source.is_file():
        raise SystemExit("lh097 source is missing")
    check_source(source); check_tangent(); check_reverse()
    print("oracle_status: pass")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
