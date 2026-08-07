#!/usr/bin/env python3
"""Independent determinant/JVP/VJP oracle for exact B01 GRADFB."""
# Exact-source semantic evidence only; no support port is generated.

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def fixed_form_body(source: Path) -> list[str]:
    lines = source.read_text(encoding="latin-1").splitlines()
    starts = [
        index for index, line in enumerate(lines)
        if re.match(r"^\s*subroutine\s+gradfb\s*\(", line, re.IGNORECASE)
    ]
    require(len(starts) == 1, "B01 must contain exactly one GRADFB declaration")
    body = []
    for line in lines[starts[0] :]:
        if line[:1].lower() in {"c", "*", "!"}:
            continue
        body.append(line[6:] if len(line) > 6 else "")
        if re.match(r"^\s*end\s*$", line, re.IGNORECASE):
            break
    return body


def source_inventory(source: Path) -> None:
    compact = re.sub(r"\s+", "", "\n".join(fixed_form_body(source))).lower()
    compact = compact.replace("&", "")
    for fragment in (
        "subroutinegradfb(x,y,z,b,c,d,vol6)",
        "implicitnone",
        "real*8b(4),c(4),d(4),x(4),y(4),z(4),vol6",
        "b(1)=y2*z34-y3*z24+y4*z23",
        "c(1)=-x2*z34+x3*z24-x4*z23",
        "d(1)=x2*y34-x3*y24+x4*y23",
        "vol6=x1*b(1)+x2*b(2)+x3*b(3)+x4*b(4)",
    ):
        require(fragment in compact, f"missing exact GRADFB fragment {fragment!r}")
    print("oracle_source_inventory: exact GRADFB determinant body pass")


def determinant_volume(x: list[float], y: list[float], z: list[float]) -> float:
    ax, ay, az = (x[i] - x[0] for i in (1, 2, 3))
    bx, by, bz = (y[i] - y[0] for i in (1, 2, 3))
    cx, cy, cz = (z[i] - z[0] for i in (1, 2, 3))
    return ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)


def source_cofactors(x: list[float], y: list[float], z: list[float]):
    z12, z13, z14 = z[1] - z[0], z[2] - z[0], z[3] - z[0]
    z23, z24, z34 = z[2] - z[1], z[3] - z[1], z[3] - z[2]
    y12, y13, y14 = y[1] - y[0], y[2] - y[0], y[3] - y[0]
    y23, y24, y34 = y[2] - y[1], y[3] - y[1], y[3] - y[2]
    b = [
        y[1] * z34 - y[2] * z24 + y[3] * z23,
        -y[0] * z34 + y[2] * z14 - y[3] * z13,
        y[0] * z24 - y[1] * z14 + y[3] * z12,
        -y[0] * z23 + y[1] * z13 - y[2] * z12,
    ]
    c = [
        -x[1] * z34 + x[2] * z24 - x[3] * z23,
        x[0] * z34 - x[2] * z14 + x[3] * z13,
        -x[0] * z24 + x[1] * z14 - x[3] * z12,
        x[0] * z23 - x[1] * z13 + x[2] * z12,
    ]
    d = [
        x[1] * y34 - x[2] * y24 + x[3] * y23,
        -x[0] * y34 + x[2] * y14 - x[3] * y13,
        x[0] * y24 - x[1] * y14 + x[3] * y12,
        -x[0] * y23 + x[1] * y13 - x[2] * y12,
    ]
    return b, c, d, math.fsum(xi * bi for xi, bi in zip(x, b))


def finite_gradient(x, y, z, variable):
    epsilon = 1.0e-6
    result = []
    slot = {"x": 0, "y": 1, "z": 2}[variable]
    for index in range(4):
        plus = [x[:], y[:], z[:]]
        minus = [x[:], y[:], z[:]]
        plus[slot][index] += epsilon
        minus[slot][index] -= epsilon
        result.append((determinant_volume(*plus) - determinant_volume(*minus)) / (2.0 * epsilon))
    return result


def check_cases() -> None:
    cases = (
        ([0.3, 1.2, -0.7, 2.1], [-1.1, 0.4, 1.8, -0.2], [0.9, -0.5, 2.4, 1.7],
         [0.2, -0.6, 0.4, 0.9], [-0.3, 0.5, 0.7, -0.2], [0.8, -0.1, 0.6, 0.3], 0.75),
        ([-2.0, 0.5, 1.3, -0.4], [0.7, -1.2, 2.2, 0.1], [1.8, 0.2, -0.9, 2.6],
         [-0.4, 0.9, -0.2, 0.1], [0.6, -0.3, 0.5, 0.8], [-0.7, 0.2, 0.4, -0.5], -1.1),
        ([1.0, 1.7, 2.5, 4.1], [2.0, 0.8, 3.4, 1.1], [-0.5, 2.2, 0.4, 3.3],
         [0.1, 0.2, -0.4, 0.3], [-0.5, 0.4, 0.2, -0.1], [0.3, -0.6, 0.7, 0.2], 2.0),
    )
    max_jvp = max_gradient = max_vjp = 0.0
    for x, y, z, dx, dy, dz, seed in cases:
        b, c, d, source_value = source_cofactors(x, y, z)
        require(abs(source_value - determinant_volume(x, y, z)) < 1.0e-12, "volume mismatch")
        epsilon = 1.0e-6
        plus = [[a + epsilon * da for a, da in zip(x, dx)],
                [a + epsilon * da for a, da in zip(y, dy)],
                [a + epsilon * da for a, da in zip(z, dz)]]
        minus = [[a - epsilon * da for a, da in zip(x, dx)],
                 [a - epsilon * da for a, da in zip(y, dy)],
                 [a - epsilon * da for a, da in zip(z, dz)]]
        numeric_jvp = (determinant_volume(*plus) - determinant_volume(*minus)) / (2.0 * epsilon)
        analytic_jvp = math.fsum(bi * vi for bi, vi in zip(b, dx))
        analytic_jvp += math.fsum(ci * vi for ci, vi in zip(c, dy))
        analytic_jvp += math.fsum(di * vi for di, vi in zip(d, dz))
        max_jvp = max(max_jvp, abs(analytic_jvp - numeric_jvp))
        for gradient, variable, direction in ((b, "x", dx), (c, "y", dy), (d, "z", dz)):
            numeric_gradient = finite_gradient(x, y, z, variable)
            max_gradient = max(max_gradient, max(abs(a - b_) for a, b_ in zip(gradient, numeric_gradient)))
            max_vjp = max(max_vjp, abs(
                seed * math.fsum(a * b_ for a, b_ in zip(gradient, direction))
                - seed * math.fsum(a * b_ for a, b_ in zip(numeric_gradient, direction))
            ))
    require(max_jvp < 1.0e-8, f"JVP error {max_jvp}")
    require(max_gradient < 1.0e-8, f"gradient error {max_gradient}")
    require(max_vjp < 1.0e-8, f"VJP error {max_vjp}")
    print(f"oracle_jvp_finite_difference: pass max_error={max_jvp:.16e}")
    print(f"oracle_gradient_finite_difference: pass max_error={max_gradient:.16e}")
    print(f"oracle_vjp_adjoint_identity: pass max_error={max_vjp:.16e}")
    print("oracle_behavioral_cases: 3")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    source = parser.parse_args().source_dir.resolve() / "program.f"
    require(source.is_file(), "B01 program.f is missing")
    source_inventory(source)
    check_cases()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
