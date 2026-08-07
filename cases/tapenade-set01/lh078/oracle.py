#!/usr/bin/env python3
"""Independent arithmetic oracle for the defined expressions in lh078.

The upstream routine reads r(3), c(1), and c(3) before assigning them.  The
oracle therefore makes those read-state values explicit.  It checks the
mathematical expressions only; it does not repair or replace the upstream
Fortran translation unit.
"""

from __future__ import annotations

import math


def primal(z: list[float]) -> list[float]:
    x = z[0:4]
    y0, y1, y2, y7 = z[4:8]
    x8 = z[8:12]
    y8 = z[12:16]
    r3, c1, c3 = z[16:19]
    return [
        x[0] ** y0,
        r3 * (x[1] * x[2]) ** (y1 * y2),
        12.0 ** (y8[3] * y8[1]),
        (x8[0] * x8[3]) ** 3.7,
        (x[3] * x[1]) ** c3,
        c1**y7,
        x8[2] ** 4.0,
    ]


def jvp(z: list[float], dz: list[float]) -> list[float]:
    x = z[0:4]
    y0, y1, y2, y7 = z[4:8]
    x8 = z[8:12]
    y8 = z[12:16]
    r3, c1, c3 = z[16:19]
    dx = dz[0:4]
    dy0, dy1, dy2, dy7 = dz[4:8]
    dx8 = dz[8:12]
    dy8 = dz[12:16]
    dr3, dc1, dc3 = dz[16:19]
    q = x[1] * x[2]
    e = y1 * y2
    q8 = x8[0] * x8[3]
    return [
        x[0] ** y0
        * (dy0 * math.log(x[0]) + y0 * dx[0] / x[0]),
        (dr3 * q**e)
        + r3
        * q**e
        * ((dy1 * y2 + y1 * dy2) * math.log(q)
           + e * (dx[1] * x[2] + x[1] * dx[2]) / q),
        12.0 ** (y8[3] * y8[1])
        * math.log(12.0)
        * (dy8[3] * y8[1] + y8[3] * dy8[1]),
        3.7 * q8**2.7 * (dx8[0] * x8[3] + x8[0] * dx8[3]),
        c3 * (x[3] * x[1]) ** (c3 - 1.0)
        * (dx[3] * x[1] + x[3] * dx[1])
        + (x[3] * x[1]) ** c3 * math.log(x[3] * x[1]) * dc3,
        c1**y7 * (dy7 * math.log(c1) + y7 * dc1 / c1),
        4.0 * x8[2] ** 3 * dx8[2],
    ]


def vjp(z: list[float], seed: list[float]) -> list[float]:
    """Transpose of the hand JVP, returned in the 19-input order."""
    x = z[0:4]
    y0, y1, y2, y7 = z[4:8]
    x8 = z[8:12]
    y8 = z[12:16]
    r3, c1, c3 = z[16:19]
    out = [0.0] * 19
    s = seed
    out[0] += s[0] * x[0] ** y0 * y0 / x[0]
    out[4] += s[0] * x[0] ** y0 * math.log(x[0])
    q = x[1] * x[2]
    e = y1 * y2
    common = s[1] * r3 * q**e
    out[16] += s[1] * q**e
    out[1] += common * e / x[1]
    out[2] += common * e / x[2]
    out[5] += common * y2 * math.log(q)
    out[6] += common * y1 * math.log(q)
    out[13] += s[2] * 12.0 ** (y8[3] * y8[1]) * math.log(12.0) * y8[3]
    out[15] += s[2] * 12.0 ** (y8[3] * y8[1]) * math.log(12.0) * y8[1]
    q8 = x8[0] * x8[3]
    common = s[3] * 3.7 * q8**2.7
    out[8] += common * x8[3]
    out[11] += common * x8[0]
    q6 = x[3] * x[1]
    common = s[4] * c3 * q6 ** (c3 - 1.0)
    out[3] += common * x[1]
    out[1] += common * x[3]
    out[18] += s[4] * q6**c3 * math.log(q6)
    common = s[5] * c1**y7
    out[7] += common * math.log(c1)
    out[17] += common * y7 / c1
    out[10] += s[6] * 4.0 * x8[2] ** 3
    return out


def check() -> None:
    z = [
        1.4, 1.2, 0.8, 1.7,
        1.1, 0.9, 1.3, 0.7,
        1.3, 0.8, 1.6, 1.1,
        0.6, 0.9, 0.8, 1.2,
        1.25, 1.4, 1.6,
    ]
    dz = [
        0.2, -0.1, 0.15, -0.05,
        0.1, 0.08, -0.06, 0.04,
        -0.07, 0.05, 0.03, -0.02,
        0.04, -0.03, 0.02, 0.01,
        0.09, -0.04, 0.06,
    ]
    seed = [0.5, -0.7, 0.8, -0.2, 0.3, -0.4, 0.6]
    eps = 1.0e-6
    fd = [
        (a - b) / (2.0 * eps)
        for a, b in zip(
            primal([a + eps * d for a, d in zip(z, dz)]),
            primal([a - eps * d for a, d in zip(z, dz)]),
        )
    ]
    tangent = jvp(z, dz)
    tangent_error = max(abs(a - b) for a, b in zip(fd, tangent))
    lhs = sum(a * b for a, b in zip(seed, tangent))
    rhs = sum(a * b for a, b in zip(vjp(z, seed), dz))
    adjoint_error = abs(lhs - rhs)
    assert tangent_error < 2.0e-8, tangent_error
    assert adjoint_error < 2.0e-12, adjoint_error
    print("finite_difference: pass")
    print(f"finite_difference_max_error: {tangent_error:.3e}")
    print("adjoint_identity: pass")
    print(f"adjoint_identity_residual: {adjoint_error:.3e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    check()
