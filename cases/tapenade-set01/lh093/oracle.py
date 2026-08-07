#!/usr/bin/env python3
"""Independent semantic oracle for the deterministic lh093 core."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_inventory(source: Path) -> None:
    text = "\n".join(
        line for line in source.read_text(encoding="latin-1").splitlines()
        if not line[:1].lower() in ("c", "!")
    ).lower()
    compact = re.sub(r"\s+", "", text)
    required = (
        "subroutinetestiomess(a,b,c,d,e)",
        "read*,b(34:66:2)",
        "write(22,*),(a(i),i=1,100,3)",
        "read(22,*),(t(i),i=0,33)",
        "b(1:33)=a(34:66)*t(1:33)",
        "write(22,*),c",
        "c=0.0",
        "read(22,*),c",
        "d=d*c",
        "read*,e",
    )
    for fragment in required:
        require(fragment in compact, f"lh093 source is missing exact fragment {fragment!r}")
    require(compact.count("read") == 4, "lh093 I/O inventory changed")
    require(compact.count("write") == 2, "lh093 WRITE inventory changed")
    print("oracle_source_inventory: pass")


def core(a: tuple[float, ...], t: tuple[float, ...], c: float, d: float) -> tuple[tuple[float, ...], float, float]:
    require(len(a) == 33 and len(t) == 33, "oracle core expects 33-element sections")
    return tuple(x * y for x, y in zip(a, t)), 0.0, d * c


def check_jvp() -> None:
    a = tuple(0.2 + 0.03 * i for i in range(33))
    t = tuple(1.1 - 0.01 * i for i in range(33))
    da = tuple(-0.1 + 0.004 * i for i in range(33))
    dt = tuple(0.07 - 0.002 * i for i in range(33))
    c, d = 0.8, -1.4
    analytic = (tuple(x * dy + dx * y for x, dx, y, dy in zip(a, da, t, dt)), 0.0, 0.0 * d + c * 0.0)
    h = 1.0e-6
    plus = core(tuple(x + h * dx for x, dx in zip(a, da)), tuple(y + h * dy for y, dy in zip(t, dt)), c, d)
    minus = core(tuple(x - h * dx for x, dx in zip(a, da)), tuple(y - h * dy for y, dy in zip(t, dt)), c, d)
    numeric = (tuple((p - m) / (2.0 * h) for p, m in zip(plus[0], minus[0])), (plus[1] - minus[1]) / (2.0 * h), (plus[2] - minus[2]) / (2.0 * h))
    require(all(math.isclose(x, y, rel_tol=2.0e-9, abs_tol=2.0e-10) for x, y in zip(analytic[0], numeric[0])), "array JVP disagrees with central difference")
    require(numeric[1:] == (0.0, 0.0), "constant c projection changed")
    print("oracle_jvp_finite_difference: pass")


def check_vjp() -> None:
    a = tuple(0.2 + 0.03 * i for i in range(33))
    t = tuple(1.1 - 0.01 * i for i in range(33))
    da = tuple(-0.1 + 0.004 * i for i in range(33))
    dt = tuple(0.07 - 0.002 * i for i in range(33))
    seed = tuple(0.5 - 0.01 * i for i in range(33))
    jvp = tuple(x * dy + dx * y for x, dx, y, dy in zip(a, da, t, dt))
    lhs = sum(s * (x * dy + dx * y) for s, x, dx, y, dy in zip(seed, a, da, t, dt))
    gradient_a = tuple(s * y for s, y in zip(seed, t))
    gradient_t = tuple(s * x for s, x in zip(seed, a))
    rhs = sum(ga * dx for ga, dx in zip(gradient_a, da)) + sum(gt * dy for gt, dy in zip(gradient_t, dt))
    require(math.isclose(lhs, rhs, rel_tol=0.0, abs_tol=1.0e-13), "array reverse dot-product identity failed")
    require(math.isclose(lhs, sum(s * y for s, y in zip(seed, jvp)), rel_tol=0.0, abs_tol=1.0e-13), "seeded output contraction failed")
    print("oracle_vjp_adjoint_identity: pass")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    source_inventory(args.source_root.resolve() / "program.f")
    check_jvp()
    check_vjp()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
