#!/usr/bin/env python3
"""Independent hand, finite-difference, and adjoint checks for lh053."""

from __future__ import annotations

import math


def binair(i: int, j: int, kind_code: int) -> float:
    return 0.15 + 0.03 * i + 0.02 * j + 0.01 * kind_code


def primal(z: list[float], tk: float, rcal: float) -> list[float]:
    nc = len(z)
    scale = rcal * tk
    tau = [[0.0 for _ in range(nc)] for _ in range(nc)]
    g = [[0.0 for _ in range(nc)] for _ in range(nc)]
    for i in range(nc - 1):
        for j in range(i + 1, nc):
            tau[i][j] = binair(i + 1, j + 1, 1) / scale
            tau[j][i] = binair(j + 1, i + 1, 1) / scale
            g[i][j] = binair(i + 1, j + 1, 2)
            g[j][i] = g[i][j]
    for j in range(nc):
        for i in range(nc):
            g[j][i] = math.exp(-g[j][i] * tau[j][i])

    v = [0.0] * nc
    w = [0.0] * nc
    for i in range(nc):
        for j in range(nc):
            zg = z[j] * g[j][i]
            v[i] += zg
            w[i] += zg * tau[j][i]
        w[i] /= v[i]

    exponent = list(w)
    for i in range(nc):
        for j in range(nc):
            exponent[i] += z[j] * g[i][j] * (tau[i][j] - w[j]) / v[j]
    return [math.exp(value) for value in exponent]


def hand_jvp(
    z: list[float], tk: float, rcal: float,
    zd: list[float], tkd: float, rcald: float,
) -> tuple[list[float], list[float]]:
    """Forward chain rule written independently of FortAD output."""

    nc = len(z)
    scale = rcal * tk
    scaled = rcald * tk + rcal * tkd
    tau = [[0.0 for _ in range(nc)] for _ in range(nc)]
    taud = [[0.0 for _ in range(nc)] for _ in range(nc)]
    g = [[0.0 for _ in range(nc)] for _ in range(nc)]
    gd = [[0.0 for _ in range(nc)] for _ in range(nc)]
    for i in range(nc - 1):
        for j in range(i + 1, nc):
            a = binair(i + 1, j + 1, 1)
            tau[i][j] = a / scale
            taud[i][j] = -a * scaled / scale**2
            a = binair(j + 1, i + 1, 1)
            tau[j][i] = a / scale
            taud[j][i] = -a * scaled / scale**2
            g[i][j] = binair(i + 1, j + 1, 2)
            g[j][i] = g[i][j]
    for j in range(nc):
        for i in range(nc):
            old = g[j][i]
            g[j][i] = math.exp(-old * tau[j][i])
            gd[j][i] = g[j][i] * (-gd[j][i] * tau[j][i] - old * taud[j][i])

    v = [0.0] * nc
    vd = [0.0] * nc
    w = [0.0] * nc
    wd = [0.0] * nc
    for i in range(nc):
        raw = 0.0
        rawd = 0.0
        for j in range(nc):
            zg = z[j] * g[j][i]
            zgd = zd[j] * g[j][i] + z[j] * gd[j][i]
            v[i] += zg
            vd[i] += zgd
            raw += zg * tau[j][i]
            rawd += zgd * tau[j][i] + zg * taud[j][i]
        w[i] = raw / v[i]
        wd[i] = (rawd * v[i] - raw * vd[i]) / v[i]**2

    exponent = list(w)
    exponent_d = list(wd)
    for i in range(nc):
        for j in range(nc):
            numerator = z[j] * g[i][j] * (tau[i][j] - w[j])
            numerator_d = (
                (zd[j] * g[i][j] + z[j] * gd[i][j]) * (tau[i][j] - w[j])
                + z[j] * g[i][j] * (taud[i][j] - wd[j])
            )
            exponent[i] += numerator / v[j]
            exponent_d[i] += numerator_d / v[j] - numerator * vd[j] / v[j]**2
    output = [math.exp(value) for value in exponent]
    output_d = [value * derivative for value, derivative in zip(output, exponent_d)]
    return output, output_d


def objective(z: list[float], tk: float, rcal: float, seed: list[float]) -> float:
    return sum(a * b for a, b in zip(primal(z, tk, rcal), seed))


def main() -> int:
    z = [1.2, 1.8, 2.4]
    tk = 0.7
    rcal = 1.3
    zd = [0.15, -0.2, 0.35]
    tkd = -0.11
    rcald = 0.08
    seed = [0.7, -0.4, 1.1]
    direction = zd + [tkd, rcald]

    values, derivatives = hand_jvp(z, tk, rcal, zd, tkd, rcald)
    value = sum(a * b for a, b in zip(values, seed))
    hand_directional = sum(a * b for a, b in zip(derivatives, seed))
    eps = 1.0e-6
    plus = objective(
        [a + eps * b for a, b in zip(z, zd)],
        tk + eps * tkd,
        rcal + eps * rcald,
        seed,
    )
    minus = objective(
        [a - eps * b for a, b in zip(z, zd)],
        tk - eps * tkd,
        rcal - eps * rcald,
        seed,
    )
    finite_difference = (plus - minus) / (2.0 * eps)
    fd_error = abs(hand_directional - finite_difference)

    gradient = []
    for index in range(len(direction)):
        x_plus = [*z, tk, rcal]
        x_minus = [*z, tk, rcal]
        x_plus[index] += eps
        x_minus[index] -= eps
        gradient.append(
            (
                objective(x_plus[:3], x_plus[3], x_plus[4], seed)
                - objective(x_minus[:3], x_minus[3], x_minus[4], seed)
            )
            / (2.0 * eps)
        )
    adjoint_residual = abs(
        sum(a * b for a, b in zip(gradient, direction)) - hand_directional
    )

    if fd_error >= 2.0e-8 or adjoint_residual >= 2.0e-8:
        raise SystemExit(
            f"oracle mismatch: fd_error={fd_error} adjoint={adjoint_residual}"
        )
    print("oracle_status: pass")
    print(f"primal_objective: {value:.17e}")
    print(f"hand_jvp: {hand_directional:.17e}")
    print(f"finite_difference: {finite_difference:.17e}")
    print(f"fd_error: {fd_error:.17e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.17e}")
    print("direction: " + " ".join(f"{item:.17e}" for item in direction))
    print("seed: " + " ".join(f"{item:.17e}" for item in seed))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
