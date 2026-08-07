#!/usr/bin/env python3
"""Independent bounded oracle for the exact B03 final flux assignments."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def source_shape(source: Path) -> None:
    text = source.read_text(encoding="latin-1")
    compact = re.sub(r"\s+", "", text.lower())
    required = (
        "subroutineviscflux",
        "common/files/",
        "common/logics/",
        "calllow(ret,trat,trat_ret,yplus)",
        "fn(2)=fn(2)-aa*txn",
        "fn(3)=fn(3)-aa*tyn",
        "fn(4)=fn(4)-aa*tzn",
        "fn(5)=fn(5)-aa*(u*txn+v*tyn+w*tzn-qn)",
    )
    missing = [fragment for fragment in required if fragment not in compact]
    if missing:
        raise AssertionError(f"B03 exact source shape changed; missing {missing!r}")
    if len(re.findall(r"^\s*subroutine\b", text, re.IGNORECASE | re.MULTILINE)) != 1:
        raise AssertionError("B03 must contain exactly one source procedure")
    print("oracle_source_shape: viscflux, COMMON, LOW call, final flux block pass")


def model(x: tuple[float, ...]) -> tuple[float, float, float, float]:
    """Model the exact final laminar block with n=(1,0,0) and fixed coefficients."""
    g21, g32, g43, g22, g31, g23, g41, g11, g51 = x
    aa = 1.7
    nx, ny, nz = 1.0, 0.0, 0.0
    muwf = 0.83
    ri = 0.61
    temperature = 1.13
    con = 0.47
    u, v, w = 0.9, -0.4, 0.25
    base2, base3, base4, base5 = 0.2, -0.3, 0.4, 0.5

    txx = 2.0 * g21
    tyy = 2.0 * g32
    tzz = 2.0 * g43
    div = (txx + tyy + tzz) / 3.0
    txx -= div
    tyy -= div
    tzz -= div
    txy = g22 + g31
    txz = g23 + g41
    tyz = 0.0  # ny=nz=0, retained to document the exact projection
    txn = muwf * (txx * nx + txy * ny + txz * nz)
    tyn = muwf * (txy * nx + tyy * ny + tyz * nz)
    tzn = muwf * (txz * nx + tyz * ny + tzz * nz)
    rn = g11 * nx
    pn = g51 * nx
    tn = ri * (pn - temperature * rn)
    qn = -con * tn
    return (
        base2 - aa * txn,
        base3 - aa * tyn,
        base4 - aa * tzn,
        base5 - aa * (u * txn + v * tyn + w * tzn - qn),
    )


def jvp(x: tuple[float, ...], dx: tuple[float, ...]) -> tuple[float, ...]:
    _ = x
    dg21, dg32, dg43, dg22, dg31, dg23, dg41, dg11, dg51 = dx
    aa = 1.7
    muwf = 0.83
    ri = 0.61
    temperature = 1.13
    con = 0.47
    u, v, w = 0.9, -0.4, 0.25
    dtxn = muwf * ((4.0 * dg21 - 2.0 * dg32 - 2.0 * dg43) / 3.0)
    dtyn = muwf * (dg22 + dg31)
    dtzn = muwf * (dg23 + dg41)
    dqn = -con * ri * (dg51 - temperature * dg11)
    return (
        -aa * dtxn,
        -aa * dtyn,
        -aa * dtzn,
        -aa * (u * dtxn + v * dtyn + w * dtzn - dqn),
    )


def vjp() -> tuple[float, ...]:
    """Hand reverse of the model for output seed (0.7,-0.2,0.4,-0.6)."""
    s2, s3, s4, s5 = 0.7, -0.2, 0.4, -0.6
    aa = 1.7
    muwf = 0.83
    ri = 0.61
    temperature = 1.13
    con = 0.47
    u, v, w = 0.9, -0.4, 0.25
    c_tx = -aa * (s2 + u * s5)
    c_ty = -aa * (s3 + v * s5)
    c_tz = -aa * (s4 + w * s5)
    c_qn = aa * s5
    return (
        c_tx * muwf * 4.0 / 3.0,
        c_tx * muwf * -2.0 / 3.0,
        c_tx * muwf * -2.0 / 3.0,
        c_ty * muwf,
        c_ty * muwf,
        c_tz * muwf,
        c_tz * muwf,
        c_qn * con * ri * temperature,
        c_qn * -con * ri,
    )


def check_jvp() -> None:
    point = (0.8, -0.3, 0.5, 0.2, -0.7, 0.4, 0.6, -0.2, 0.9)
    direction = (0.11, -0.13, 0.17, -0.19, 0.23, -0.29, 0.31, 0.37, -0.41)
    epsilon = 1.0e-6
    plus = model(tuple(a + epsilon * b for a, b in zip(point, direction)))
    minus = model(tuple(a - epsilon * b for a, b in zip(point, direction)))
    finite_difference = tuple((a - b) / (2.0 * epsilon) for a, b in zip(plus, minus))
    hand = jvp(point, direction)
    if not all(
        math.isclose(a, b, rel_tol=2.0e-8, abs_tol=2.0e-9)
        for a, b in zip(hand, finite_difference)
    ):
        raise AssertionError(f"JVP finite-difference mismatch: hand={hand} fd={finite_difference}")
    print("oracle_jvp: final tensor/heat-flux model agrees with central differences")


def check_vjp() -> None:
    point = (0.8, -0.3, 0.5, 0.2, -0.7, 0.4, 0.6, -0.2, 0.9)
    direction = (0.11, -0.13, 0.17, -0.19, 0.23, -0.29, 0.31, 0.37, -0.41)
    seeds = (0.7, -0.2, 0.4, -0.6)
    tangent = jvp(point, direction)
    gradient = vjp()
    lhs = sum(seed * delta for seed, delta in zip(seeds, tangent))
    rhs = sum(component * delta for component, delta in zip(gradient, direction))
    if not math.isclose(lhs, rhs, rel_tol=1.0e-13, abs_tol=1.0e-13):
        raise AssertionError(f"VJP dot-product mismatch: lhs={lhs} rhs={rhs}")
    print("oracle_vjp: hand Jacobian-transpose dot-product identity passes")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    source = args.source_root.resolve() / "program.f"
    if not source.is_file():
        raise SystemExit("B03 exact source is missing")
    source_shape(source)
    check_jvp()
    check_vjp()
    print("oracle_domain: fixed unit normal and laminar coefficients; no repaired port")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
