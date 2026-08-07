#!/usr/bin/env python3
"""Independent bounded oracle for lh094's DISACTIVATE summary boundary."""
from __future__ import annotations
import argparse
import math
import re
from pathlib import Path

def witness(a: float, b: float) -> float:
    return b + a + a * a

def jvp(a: float, da: float, db: float) -> float:
    return db + (1.0 + 2.0 * a) * da

def vjp(a: float, seed: float) -> tuple[float, float]:
    return seed * (1.0 + 2.0 * a), seed

def check_source(source_root: Path) -> None:
    source = source_root / "program.f"
    compact = re.sub(r"\s+", "", source.read_text(encoding="latin-1").lower())
    required = ("subroutinetest(a,b)", "s=a*a", "s=disactivate(s)", "b=a+b+s")
    if any(fragment not in compact for fragment in required):
        raise SystemExit("lh094 exact source shape changed")
    summary = (source.parent / "MyGeneralLib").read_text(encoding="latin-1").lower()
    if "function disactivate" not in summary or "readnotwritten:(1,0)" not in summary or "type:(float(), float())" not in summary:
        raise SystemExit("DISACTIVATE summary boundary changed")
    print("oracle_source: exact algebra and external identity-summary boundary pass")

def check_jvp() -> None:
    a, b, da, db, eps = 0.4, -0.7, 0.8, -0.2, 1.0e-7
    fd = (witness(a + eps * da, b + eps * db) - witness(a - eps * da, b - eps * db)) / (2.0 * eps)
    if not math.isclose(jvp(a, da, db), fd, rel_tol=1e-8, abs_tol=1e-8):
        raise SystemExit("JVP finite-difference mismatch")
    print("oracle_jvp: summary-level tangent agrees with central difference")

def check_vjp() -> None:
    a, b, da, db, seed, eps = -0.3, 0.2, 0.6, -0.9, 1.7, 1.0e-7
    ga, gb = vjp(a, seed)
    lhs = seed * (witness(a + eps * da, b + eps * db) - witness(a - eps * da, b - eps * db)) / (2.0 * eps)
    if not math.isclose(lhs, ga * da + gb * db, rel_tol=1e-8, abs_tol=1e-8):
        raise SystemExit("VJP dot-product identity mismatch")
    print("oracle_vjp: summary-level reverse dot-product identity pass")

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    check_source(parser.parse_args().source_root.resolve())
    check_jvp()
    check_vjp()
    print("oracle_status: pass")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
