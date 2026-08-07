#!/usr/bin/env python3
"""Independent hand-JVP and central-difference oracle for bounded lh051."""

from __future__ import annotations

import math


def state() -> tuple[list[float], list[float], list[float]]:
    """Return a deterministic 1-based state with enough room for j=102."""
    x = [0.0] + [0.17 + 0.013 * i for i in range(1, 121)]
    y = [0.0] + [-0.31 + 0.009 * i for i in range(1, 121)]
    z = [0.0] + [0.23 - 0.011 * i for i in range(1, 121)]
    return x, y, z


def primal(x: list[float], y: list[float], z: list[float], n: int = 60, o: int = 0):
    x, y, z = x[:], y[:], z[:]
    a = 0.5 * x[20]
    for i in range(5 + o, n + 1, 2):
        z[i] = z[i - 1] - 2.0 * z[i] + z[i + 1]
        x[i] = 3.0 * x[i] - y[i + 1] * y[i - 1]
    a = x[10] + a
    j = 0
    for _ in range(34):
        j += 3
        x[j] = a * y[j - 1]
        y[j + 1] = z[j] * z[3] + x[j + 1]
    a = 2.0 * a + 3.0
    return x, y, z


def hand_jvp(x, y, z, xd, yd, zd, n: int = 60, o: int = 0):
    x, y, z = x[:], y[:], z[:]
    xd, yd, zd = xd[:], yd[:], zd[:]
    a = 0.5 * x[20]
    ad = 0.5 * xd[20]
    for i in range(5 + o, n + 1, 2):
        zd[i] = zd[i - 1] - 2.0 * zd[i] + zd[i + 1]
        z[i] = z[i - 1] - 2.0 * z[i] + z[i + 1]
        xd[i] = 3.0 * xd[i] - y[i + 1] * yd[i - 1] - y[i - 1] * yd[i + 1]
        x[i] = 3.0 * x[i] - y[i + 1] * y[i - 1]
    ad = xd[10] + ad
    a = x[10] + a
    j = 0
    for _ in range(34):
        j += 3
        xd[j] = ad * y[j - 1] + a * yd[j - 1]
        x[j] = a * y[j - 1]
        yd[j + 1] = zd[j] * z[3] + z[j] * zd[3] + xd[j + 1]
        y[j + 1] = z[j] * z[3] + x[j + 1]
    return x, y, z, xd, yd, zd


def max_error(left, right):
    return max(abs(a - b) for a, b in zip(left, right))


def main() -> int:
    x, y, z = state()
    xd = [0.0] + [0.003 - 0.0007 * i for i in range(1, 121)]
    yd = [0.0] + [-0.002 + 0.0005 * i for i in range(1, 121)]
    zd = [0.0] + [0.001 + 0.0004 * i for i in range(1, 121)]

    hand = hand_jvp(x, y, z, xd, yd, zd)
    primal_plus = primal(
        [a + 1.0e-6 * b for a, b in zip(x, xd)],
        [a + 1.0e-6 * b for a, b in zip(y, yd)],
        [a + 1.0e-6 * b for a, b in zip(z, zd)],
    )
    primal_minus = primal(
        [a - 1.0e-6 * b for a, b in zip(x, xd)],
        [a - 1.0e-6 * b for a, b in zip(y, yd)],
        [a - 1.0e-6 * b for a, b in zip(z, zd)],
    )
    finite = tuple(
        (plus - minus) / (2.0e-6)
        for plus, minus in zip(
            primal_plus[0] + primal_plus[1] + primal_plus[2],
            primal_minus[0] + primal_minus[1] + primal_minus[2],
        )
    )
    analytical = hand[3] + hand[4] + hand[5]
    error = max_error(analytical, finite)
    if not math.isfinite(error) or error > 2.0e-8:
        raise SystemExit(f"finite-difference mismatch: {error}")
    print(f"oracle_status: pass max_fd_error={error:.3e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
