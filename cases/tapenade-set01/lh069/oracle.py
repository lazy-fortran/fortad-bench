#!/usr/bin/env python3
"""Independent JVP/VJP, finite-difference, and adjoint oracle for lh069."""

from __future__ import annotations

import math


def state() -> tuple[list[float], list[float]]:
    a = [0.0] + [0.0] * 10
    b = [0.0] + [0.0] * 10
    for i in range(1, 11):
        a[i] = 0.2 + 0.07 * i
        b[i] = -0.4 + 0.11 * i
    a[2] = 0.9
    a[4] = 1.0
    a[8] = 0.0
    b[8] = 10.0
    return a, b


def check_path(a: list[float], b: list[float], n: int) -> None:
    if n != 10 or not (4.0 * a[4] > a[8]) or not (4.0 * a[4] <= b[8]):
        raise ValueError("oracle point is outside the one-iteration terminating path")


def primal(a: list[float], b: list[float], n: int = 10) -> tuple[list[float], list[float]]:
    a = a[:]
    b = b[:]
    check_path(a, b, n)
    a[1] = 2.0 * a[2]
    while True:
        a[3] = 4.0 * a[4]
        if a[3] <= a[8]:
            break
        a[5] = 6.0 * a[6]
        for i in range(5, n + 1):
            a[i] = b[i]
    a[7] = 8.0 * a[8]
    return a, b


def hand_jvp(a: list[float], b: list[float], ad: list[float], bd: list[float], n: int = 10):
    a = a[:]
    b = b[:]
    ad = ad[:]
    bd = bd[:]
    check_path(a, b, n)
    ad[1] = 2.0 * ad[2]
    a[1] = 2.0 * a[2]
    ad[3] = 4.0 * ad[4]
    a[3] = 4.0 * a[4]
    if a[3] > a[8]:
        ad[5] = 6.0 * ad[6]
        a[5] = 6.0 * a[6]
        for i in range(5, n + 1):
            ad[i] = bd[i]
            a[i] = b[i]
    ad[7] = 8.0 * ad[8]
    a[7] = 8.0 * a[8]
    return a, b, ad, bd


def hand_vjp(a: list[float], b: list[float], a_bar: list[float], b_bar: list[float], n: int = 10):
    a = a[:]
    b = b[:]
    a_bar = a_bar[:]
    b_bar = b_bar[:]
    check_path(a, b, n)
    a_bar[8] += 8.0 * a_bar[7]
    a_bar[7] = 0.0
    for i in range(n, 4, -1):
        b_bar[i] += a_bar[i]
        a_bar[i] = 0.0
    a_bar[6] += 6.0 * a_bar[5]
    a_bar[5] = 0.0
    a_bar[4] += 4.0 * a_bar[3]
    a_bar[3] = 0.0
    a_bar[2] += 2.0 * a_bar[1]
    a_bar[1] = 0.0
    return a_bar, b_bar


def main() -> int:
    a, b = state()
    ad = [0.0] + [0.013 - 0.001 * i for i in range(1, 11)]
    bd = [0.0] + [-0.021 + 0.002 * i for i in range(1, 11)]
    ah, bh, adh, bdh = hand_jvp(a, b, ad, bd)
    for step in (1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5):
        plus = primal([x + step * dx for x, dx in zip(a, ad)], [x + step * dx for x, dx in zip(b, bd)])
        minus = primal([x - step * dx for x, dx in zip(a, ad)], [x - step * dx for x, dx in zip(b, bd)])
        finite = [
            (x_plus - x_minus) / (2.0 * step)
            for x_plus, x_minus in zip(plus[0] + plus[1], minus[0] + minus[1])
        ]
        analytical = adh + bdh
        error = max(abs(x - y) for x, y in zip(analytical, finite))
        if not math.isfinite(error) or error > 3.0e-8:
            raise SystemExit(f"finite-difference mismatch at h={step}: {error}")

    a_seed = [0.0] + [0.031 - 0.002 * i for i in range(1, 11)]
    b_seed = [0.0] + [-0.017 + 0.003 * i for i in range(1, 11)]
    a_bar, b_bar = hand_vjp(a, b, a_seed, b_seed)
    lhs = sum(x * y for x, y in zip(adh + bdh, a_seed + b_seed))
    rhs = sum(x * y for x, y in zip(ad + bd, a_bar + b_bar))
    adjoint_error = abs(lhs - rhs)
    if not math.isfinite(adjoint_error) or adjoint_error > 3.0e-12:
        raise SystemExit(f"adjoint mismatch: {adjoint_error}")
    print("numeric_hand_jvp: pass")
    print("numeric_hand_vjp: pass")
    print("finite_difference: pass")
    print("adjoint_identity: pass")
    print(f"oracle_status: pass max_fd_error={error:.3e} adjoint_error={adjoint_error:.3e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
