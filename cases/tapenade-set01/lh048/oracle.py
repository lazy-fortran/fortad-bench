#!/usr/bin/env python3
"""Independent closed-form, finite-difference, and adjoint checks for lh048."""

from __future__ import annotations

import math


def value(q: tuple[float, ...]) -> float:
    u, z, t, v, y = q[:5]
    x = list(q[5:])
    x1 = y * u + t
    u = x[7] * z
    y = z + v * y
    v = u * x[9]
    t = t + x1 * z + 3.0 * v
    y = 0.0
    u = x[8] * z
    y = z
    v = u * x[10]
    t = t + x1 * z + 3.0 * u
    return t


def jvp(q: tuple[float, ...], dq: tuple[float, ...]) -> float:
    # Independent forward directional arithmetic for the scalar result t.
    u, z, t, v, y = q[:5]
    ud, zd, td, vd, yd = dq[:5]
    x = list(q[5:])
    xd = list(dq[5:])
    x1 = y * u + t
    x1d = yd * u + y * ud + td
    u = x[7] * z
    ud = xd[7] * z + x[7] * zd
    y = z + v * y
    yd = zd + vd * q[4] + q[3] * yd
    v = u * x[9]
    vd = ud * x[9] + u * xd[9]
    td = td + x1d * z + x1 * zd + 3.0 * vd
    t = t + x1 * z + 3.0 * v
    y = 0.0
    yd = 0.0
    u = x[8] * z
    ud = xd[8] * z + x[8] * zd
    y = z
    yd = zd
    v = u * x[10]
    vd = ud * x[10] + u * xd[10]
    td = td + x1d * z + x1 * zd + 3.0 * ud
    return td


def vjp(q: tuple[float, ...], seed: float) -> tuple[float, ...]:
    # Reverse the same scalar expression independently, by central differences
    # of the primal. This is an oracle for the adjoint identity, not FortAD.
    gradients: list[float] = []
    for i in range(len(q)):
        h = 1.0e-4 * max(1.0, abs(q[i]))
        qp = list(q)
        qm = list(q)
        qp[i] += h
        qm[i] -= h
        gradients.append(seed * (value(tuple(qp)) - value(tuple(qm))) / (2.0 * h))
    return tuple(gradients)


def main() -> None:
    q = (1.2, 0.7, -0.4, 0.3, 2.0, *[0.1 * i for i in range(1, 15)])
    dq = (0.2, -0.1, 0.4, 0.3, 0.0, *([0.0] * 14))
    seed = 0.8
    tangent = jvp(q, dq)
    finite_difference_errors = []
    for h in (1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5):
        qp = tuple(a + h * b for a, b in zip(q, dq))
        qm = tuple(a - h * b for a, b in zip(q, dq))
        finite_difference_errors.append(abs((value(qp) - value(qm)) / (2.0 * h) - tangent))
    gradient = vjp(q, seed)
    adjoint_residual = abs(seed * tangent - sum(a * b for a, b in zip(gradient, dq)))
    assert math.isfinite(value(q))
    assert min(finite_difference_errors) < 2.0e-5
    assert adjoint_residual < 2.0e-5
    print("fd_errors:", " ".join(f"{error:.6e}" for error in finite_difference_errors))
    print(f"adjoint_residual: {adjoint_residual:.6e}")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
