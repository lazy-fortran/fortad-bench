#!/usr/bin/env python3
"""Independent numerical oracle for v547's indexed array pipeline.

This model does not invoke Fortran, Tapenade, or FortAD.  It evaluates the
three source operations (indexed overwrite, indexed addition, and indexed
accumulation) with repeated indices, then checks a hand JVP and VJP against a
central difference and the adjoint identity.
"""

from __future__ import annotations

import math


INDICES = ([0, 0, 1], [1, 0, 2], [2, 1, 0])
COMMON_C = [1.5, -2.0, 0.75, 4.0, -1.0, 2.5, 0.0, 0.0, 0.0, 0.0]
COMMON_D = [0.5, 1.5, -1.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
COMMON_E = [5.0, -3.0, 1.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
COMMON_F = [0.25, -0.5, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


def primal(bb: list[float]) -> float:
    aind, bind, cind = INDICES
    c = COMMON_C.copy()
    e = COMMON_E.copy()
    a = [0.0] * 10
    for i in range(3):
        c[aind[i]] = bb[bind[i]] * COMMON_D[cind[i]]
    for i in range(3):
        e[aind[i]] = c[bind[i]] + COMMON_F[cind[i]]
    for i in range(3):
        a[aind[i]] += e[bind[i]] * e[cind[i]]
    return a[0]


def jvp(bb: list[float], dbb: list[float]) -> float:
    aind, bind, cind = INDICES
    c = COMMON_C.copy()
    dc = [0.0] * 10
    e = COMMON_E.copy()
    de = [0.0] * 10
    da = [0.0] * 10
    for i in range(3):
        c[aind[i]] = bb[bind[i]] * COMMON_D[cind[i]]
        dc[aind[i]] = dbb[bind[i]] * COMMON_D[cind[i]]
    for i in range(3):
        e[aind[i]] = c[bind[i]] + COMMON_F[cind[i]]
        de[aind[i]] = dc[bind[i]]
    for i in range(3):
        da[aind[i]] += de[bind[i]] * e[cind[i]] + e[bind[i]] * de[cind[i]]
    return da[0]


def vjp(bb: list[float], seed: float) -> list[float]:
    aind, bind, cind = INDICES
    c = COMMON_C.copy()
    e = COMMON_E.copy()
    for i in range(3):
        c[aind[i]] = bb[bind[i]] * COMMON_D[cind[i]]
    for i in range(3):
        e[aind[i]] = c[bind[i]] + COMMON_F[cind[i]]

    ae = [0.0] * 10
    aa = [seed] + [0.0] * 9
    for i in range(2, -1, -1):
        ae[bind[i]] += aa[aind[i]] * e[cind[i]]
        ae[cind[i]] += aa[aind[i]] * e[bind[i]]
    ac = [0.0] * 10
    for i in range(2, -1, -1):
        ac[bind[i]] += ae[aind[i]]
        ae[aind[i]] = 0.0
    dbb = [0.0] * 3
    for i in range(2, -1, -1):
        dbb[bind[i]] += ac[aind[i]] * COMMON_D[cind[i]]
        ac[aind[i]] = 0.0
    return dbb


def main() -> None:
    bb = [1.1, -0.7, 0.4]
    direction = [0.2, -0.35, 0.15]
    seed = 1.75
    epsilon = 1.0e-6
    plus = primal([x + epsilon * dx for x, dx in zip(bb, direction)])
    minus = primal([x - epsilon * dx for x, dx in zip(bb, direction)])
    numerical = (plus - minus) / (2.0 * epsilon)
    tangent = jvp(bb, direction)
    finite_difference_error = abs(numerical - tangent)
    adjoint_left = seed * tangent
    adjoint_right = sum(x * dx for x, dx in zip(vjp(bb, seed), direction))
    adjoint_residual = abs(adjoint_left - adjoint_right)
    assert math.isfinite(finite_difference_error)
    assert math.isfinite(adjoint_residual)
    assert finite_difference_error < 1.0e-8, finite_difference_error
    assert adjoint_residual < 1.0e-12, adjoint_residual
    print("model: xmul indexed overwrite; xadd indexed overwrite; xdot indexed accumulation")
    print(f"primal_endval: {primal(bb):.16e}")
    print(f"finite_difference_max_error: {finite_difference_error:.16e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.16e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
