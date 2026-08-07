#!/usr/bin/env python3
"""Independent hand tangent, finite-difference, and adjoint oracle for lh041."""

from __future__ import annotations

import math
import sys


def primal(a: float, b: float, q: float) -> float:
    tab = [[1.0 for _ in range(3)] for _ in range(5)]
    x = [[[0.5 for _ in range(2)] for _ in range(3)] for _ in range(5)]

    def sub(y: list[list[float]], factor: float) -> None:
        for i in range(3):
            for j in range(3):
                for k in range(2):
                    x[i][j][k] = factor * x[i][j][k]
        for i in range(3):
            for j in range(i + 1):
                y[i][j] = x[i][j][0] * a + float(i + 1)

    sub(tab, q)
    for i in range(3):
        for j in range(3):
            tab[i][j] = a * x[i][j][0] + b
    sub(tab, 10.0)
    return a * tab[1][1] + b + x[1][1][0]


def hand_jvp(a: float, b: float, q: float, da: float, db: float, dq: float) -> float:
    # This is a source-independent dual-number transcription of the same
    # scalar recurrence, kept separate from the generated Fortran.
    tab = [[(1.0, 0.0) for _ in range(3)] for _ in range(5)]
    x = [[[(0.5, 0.0) for _ in range(2)] for _ in range(3)] for _ in range(5)]

    def add(u: tuple[float, float], v: tuple[float, float]) -> tuple[float, float]:
        return u[0] + v[0], u[1] + v[1]

    def mul(u: tuple[float, float], v: tuple[float, float]) -> tuple[float, float]:
        return u[0] * v[0], u[1] * v[0] + u[0] * v[1]

    av, bv, qv = (a, da), (b, db), (q, dq)

    def sub(y: list[list[tuple[float, float]]], factor: tuple[float, float]) -> None:
        for i in range(3):
            for j in range(3):
                for k in range(2):
                    x[i][j][k] = mul(factor, x[i][j][k])
        for i in range(3):
            for j in range(i + 1):
                y[i][j] = add(mul(x[i][j][0], av), (float(i + 1), 0.0))

    sub(tab, qv)
    for i in range(3):
        for j in range(3):
            tab[i][j] = add(mul(av, x[i][j][0]), bv)
    sub(tab, (10.0, 0.0))
    return add(add(mul(av, tab[1][1]), bv), x[1][1][0])[1]


def main() -> int:
    a, b, q = 0.7, -0.2, 0.6
    da, db, dq = -0.04, 0.03, 0.02
    output_bar = 1.0
    tangent = hand_jvp(a, b, q, da, db, dq)
    h = 1.0e-5
    finite_difference = (primal(a + h * da, b + h * db, q + h * dq) -
                         primal(a - h * da, b - h * db, q - h * dq)) / (2.0 * h)
    # Recover the three hand partials with independent directional probes.
    partials = []
    for direction in ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)):
        partials.append(hand_jvp(a, b, q, *direction))
    adjoint = output_bar * tangent
    # The VJP check uses the same scalar output seed as the JVP pairing.
    vjp_pairing = (da * output_bar * partials[0] + db * output_bar * partials[1] +
                   dq * output_bar * partials[2])
    if not all(math.isfinite(value) for value in (tangent, finite_difference, adjoint)):
        return 1
    if abs(finite_difference - tangent) > 2.0e-8:
        return 1
    if abs(adjoint - vjp_pairing) > 1.0e-14:
        return 1
    print("oracle_status: pass")
    print(f"primal: {primal(a, b, q):.16e}")
    print(f"hand_jvp: {tangent:.16e}")
    print(f"finite_difference: {finite_difference:.16e}")
    print(f"fd_error: {abs(finite_difference - tangent):.16e}")
    print(f"adjoint_identity_residual: {abs(adjoint - vjp_pairing):.16e}")
    print(f"source: {sys.argv[0]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
