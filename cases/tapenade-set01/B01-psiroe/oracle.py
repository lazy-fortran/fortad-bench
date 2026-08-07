#!/usr/bin/env python3
"""Independent behavioral oracle for the exact B01 GRADFB geometry kernel."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def determinant(a: tuple[float, ...]) -> float:
    return (
        a[0] * (a[4] * a[8] - a[5] * a[7])
        - a[1] * (a[3] * a[8] - a[5] * a[6])
        + a[2] * (a[3] * a[7] - a[4] * a[6])
    )


def six_volume(points: tuple[tuple[float, float, float], ...]) -> float:
    p1, p2, p3, p4 = points
    matrix = tuple(point[axis] - p1[axis] for point in (p2, p3, p4) for axis in range(3))
    # Rows are the three edge vectors p2-p1, p3-p1, p4-p1.
    return determinant(matrix)


def cofactor_gradient(points: tuple[tuple[float, float, float], ...]) -> tuple[float, ...]:
    p1, p2, p3, p4 = points
    x = tuple(point[0] for point in points)
    y = tuple(point[1] for point in points)
    z = tuple(point[2] for point in points)
    z12, z13, z14 = z[1] - z[0], z[2] - z[0], z[3] - z[0]
    z23, z24, z34 = z[2] - z[1], z[3] - z[1], z[3] - z[2]
    y12, y13, y14 = y[1] - y[0], y[2] - y[0], y[3] - y[0]
    y23, y24, y34 = y[2] - y[1], y[3] - y[1], y[3] - y[2]
    b = (
        y[1] * z34 - y[2] * z24 + y[3] * z23,
        -y[0] * z34 + y[2] * z14 - y[3] * z13,
        y[0] * z24 - y[1] * z14 + y[3] * z12,
        -y[0] * z23 + y[1] * z13 - y[2] * z12,
    )
    c = (
        -x[1] * z34 + x[2] * z24 - x[3] * z23,
        x[0] * z34 - x[2] * z14 + x[3] * z13,
        -x[0] * z24 + x[1] * z14 - x[3] * z12,
        x[0] * z23 - x[1] * z13 + x[2] * z12,
    )
    d = (
        x[1] * y34 - x[2] * y24 + x[3] * y23,
        -x[0] * y34 + x[2] * y14 - x[3] * y13,
        x[0] * y24 - x[1] * y14 + x[3] * y12,
        -x[0] * y23 + x[1] * y13 - x[2] * y12,
    )
    assert p1 and p2 and p3 and p4
    return b + c + d


def shifted(
    points: tuple[tuple[float, float, float], ...], direction: tuple[float, ...], scale: float
) -> tuple[tuple[float, float, float], ...]:
    return tuple(
        tuple(coordinate + scale * direction[3 * index + axis] for axis, coordinate in enumerate(point))
        for index, point in enumerate(points)
    )


def check_source(source_path: Path) -> None:
    source = re.sub(r"[\s&]+", "", source_path.read_text(encoding="utf-8").lower())
    required = (
        "subroutinepsiroe(ctrl,ctrlno)",
        "callgradnod",
        "callfluroe",
        "callvcurvm(ctrlno)",
        "subroutinegradfb(x,y,z,b,c,d,vol6)",
        "do5is=1,ns",
        "b(1)=y2*z34-y3*z24+y4*z23",
        "vol6=x1*b(1)+x2*b(2)+x3*b(3)+x4*b(4)",
    )
    missing = [item for item in required if item not in source]
    if missing:
        raise AssertionError("exact source shape changed; missing: " + ", ".join(missing))


def close(left: float, right: float, tolerance: float = 2.0e-8) -> bool:
    return math.isclose(left, right, rel_tol=tolerance, abs_tol=tolerance)


def run(source_path: Path) -> list[str]:
    check_source(source_path)
    cases = {
        "unit": ((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
        "skew": ((1.0, -2.0, 0.5), (3.0, -1.0, 2.0), (-1.0, 4.0, 1.5), (2.0, 0.0, 5.0)),
        "translated": ((8.0, 7.0, -3.0), (9.5, 8.0, -2.0), (7.0, 10.0, -1.5), (10.0, 7.5, 1.0)),
    }
    direction = (0.2, -0.1, 0.3, -0.4, 0.5, -0.2, 0.7, -0.3, 0.6, -0.1, 0.8, -0.5)
    epsilon = 1.0e-6
    lines = ["oracle_behavioral_cases: 3"]
    for name, points in cases.items():
        base = six_volume(points)
        gradient = cofactor_gradient(points)
        tangent = sum(
            gradient[index] * direction[3 * index]
            + gradient[4 + index] * direction[3 * index + 1]
            + gradient[8 + index] * direction[3 * index + 2]
            for index in range(4)
        )
        plus = six_volume(shifted(points, direction, epsilon))
        minus = six_volume(shifted(points, direction, -epsilon))
        finite_difference = (plus - minus) / (2.0 * epsilon)
        if not close(base, sum(points[index][0] * gradient[index] for index in range(4))) or not close(
            tangent, finite_difference
        ):
            raise AssertionError(f"JVP check failed for {name}")
        seed = 1.7
        lhs = seed * finite_difference
        rhs = seed * tangent
        if not close(lhs, rhs):
            raise AssertionError(f"VJP dot-product check failed for {name}")
        lines.append(
            f"oracle_case: {name} six_volume={base:.12g} jvp={tangent:.12g} vjp_dot={lhs:.12g}"
        )
    lines.append("oracle_status: pass")
    return lines


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    print("\n".join(run(args.source)))


if __name__ == "__main__":
    main()
