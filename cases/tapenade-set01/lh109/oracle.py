#!/usr/bin/env python3
"""Independent bounded arithmetic oracle for the lh109 evidence package.

The exact ADJ3 source has undefined locals, COMMON/argument aliasing, and a
type-mismatched call.  Consequently this file does not execute or repair that
procedure.  It inventories the exact source and tests the deterministic SUB1
assignment sequence in a separately named model with explicit initial values.
"""

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
        "subroutineadj3(z,t)",
        "subroutinesub1(u,y2,z,v)",
        "common/cc/x,y",
        "i=5",
        "x(1)=y*z+t",
        "callsub1(u,x(i),z,v)",
        "x(j)=x(i)*x(j)",
        "t=t+x(1)*z+3*v",
        "u=u*y+y2(3)*z",
        "x(3)=0.0",
        "y=z+v*y",
        "v=u*y2(5)",
    )
    for fragment in required:
        require(fragment in compact, f"lh109 source inventory missing {fragment!r}")
    require(compact.count("common/cc/x,y") == 2, "lh109 COMMON inventory changed")
    print("oracle_source_inventory: pass")


def sub1_model(u: float, y2_3: float, y2_5: float, z: float,
               v: float, y: float) -> tuple[float, float, float]:
    """Bounded model of SUB1's scalar assignments, in source order."""
    u_out = u * y + y2_3 * z
    y_out = z + v * y
    v_out = u_out * y2_5
    return u_out, y_out, v_out


def jvp(u: float, y2_3: float, y2_5: float, z: float, v: float, y: float,
        du: float, dy2_3: float, dy2_5: float, dz: float, dv: float,
        dy: float) -> tuple[float, float, float]:
    u_out = u * y + y2_3 * z
    du_out = du * y + u * dy + dy2_3 * z + y2_3 * dz
    dy_out = dz + dv * y + v * dy
    dv_out = y2_5 * du_out + u_out * dy2_5
    return du_out, dy_out, dv_out


def vjp(u: float, y2_3: float, y2_5: float, z: float, v: float, y: float,
        seed: tuple[float, float, float]) -> tuple[float, float, float, float, float, float]:
    u_out = u * y + y2_3 * z
    su, sy, sv = seed
    shared = su + sv * y2_5
    return (
        y * shared,
        z * shared,
        sv * u_out,
        y2_3 * shared + sy,
        sy * y,
        u * shared + sy * v,
    )


def check_primal() -> None:
    values = sub1_model(0.7, -0.4, 1.3, 0.9, -0.2, 1.1)
    expected = (0.7 * 1.1 + (-0.4) * 0.9,
                0.9 + (-0.2) * 1.1,
                (0.7 * 1.1 + (-0.4) * 0.9) * 1.3)
    require(all(math.isclose(actual, want, rel_tol=0.0, abs_tol=1.0e-15)
                for actual, want in zip(values, expected)),
            "bounded SUB1 primal assignment order changed")
    print("oracle_bounded_primal: pass")


def check_jvp() -> None:
    point = (0.7, -0.4, 1.3, 0.9, -0.2, 1.1)
    direction = (-0.3, 0.6, -0.5, 0.2, 0.4, -0.7)
    analytic = jvp(*point, *direction)
    h = 1.0e-7
    plus = sub1_model(*(x + h * dx for x, dx in zip(point, direction)))
    minus = sub1_model(*(x - h * dx for x, dx in zip(point, direction)))
    numeric = tuple((p - m) / (2.0 * h) for p, m in zip(plus, minus))
    require(all(math.isclose(actual, want, rel_tol=2.0e-9, abs_tol=2.0e-10)
                for actual, want in zip(analytic, numeric)),
            f"bounded SUB1 JVP disagrees with central difference: {analytic} != {numeric}")
    print("oracle_jvp_finite_difference: pass")


def check_vjp() -> None:
    point = (0.7, -0.4, 1.3, 0.9, -0.2, 1.1)
    direction = (-0.3, 0.6, -0.5, 0.2, 0.4, -0.7)
    seed = (0.8, -1.2, 0.5)
    tangent = sum(seed_i * tangent_i for seed_i, tangent_i in
                  zip(seed, jvp(*point, *direction)))
    gradient = vjp(*point, seed)
    cotangent = sum(gradient_i * direction_i
                    for gradient_i, direction_i in zip(gradient, direction))
    require(math.isclose(tangent, cotangent, rel_tol=0.0, abs_tol=1.0e-14),
            f"bounded SUB1 VJP dot-product identity failed: {tangent} != {cotangent}")
    print("oracle_vjp_dot_product: pass")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    source_inventory(parser.parse_args().source_root.resolve() / "program.f")
    check_primal()
    check_jvp()
    check_vjp()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
