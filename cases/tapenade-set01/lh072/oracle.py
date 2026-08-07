#!/usr/bin/env python3
"""Independent numerical oracle for the bounded lh072 specialization."""

from __future__ import annotations

import math


def primal(a: list[float], b: list[float]) -> tuple[list[float], list[float]]:
    a_out = [a_i * b_i for a_i, b_i in zip(a, b)]
    b_out = list(b)
    b_out[3] = b[3] * b[3]
    b_out[9] = b[9] * b[9]
    return a_out, b_out


def jvp(a: list[float], b: list[float], ad: list[float], bd: list[float]) -> tuple[list[float], list[float]]:
    a_d = [bd_i * a_i + b_i * ad_i for a_i, b_i, ad_i, bd_i in zip(a, b, ad, bd)]
    b_d = list(bd)
    b_d[3] = 2.0 * b[3] * bd[3]
    b_d[9] = 2.0 * b[9] * bd[9]
    return a_d, b_d


def max_error(left: list[float], right: list[float]) -> float:
    return max(abs(x - y) for x, y in zip(left, right))


def main() -> None:
    a = [0.17 * i - 0.4 for i in range(1, 11)]
    b = [-0.11 * i + 1.4 for i in range(1, 11)]
    ad = [0.013 * i - 0.03 for i in range(1, 11)]
    bd = [-0.009 * i + 0.04 for i in range(1, 11)]
    seed = [0.07 * i - 0.2 for i in range(1, 11)]

    a_out, b_out = primal(a, b)
    a_d, b_d = jvp(a, b, ad, bd)
    a_in_b = [seed_i * b_i for seed_i, b_i in zip(seed, b)]
    b_in_b = [seed_i * a_i for seed_i, a_i in zip(seed, a)]

    finite_difference_max = 0.0
    for h in (1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5):
        a_plus, _ = primal([x + h * dx for x, dx in zip(a, ad)],
                           [x + h * dx for x, dx in zip(b, bd)])
        a_minus, _ = primal([x - h * dx for x, dx in zip(a, ad)],
                            [x - h * dx for x, dx in zip(b, bd)])
        finite_difference_max = max(
            finite_difference_max,
            max_error([(x - y) / (2.0 * h) for x, y in zip(a_plus, a_minus)], a_d),
        )

    lhs = math.fsum(seed_i * d_i for seed_i, d_i in zip(seed, a_d))
    rhs = math.fsum(x * dx for x, dx in zip(a_in_b, ad)) + math.fsum(
        x * dx for x, dx in zip(b_in_b, bd)
    )
    adjoint_residual = abs(lhs - rhs)
    callback_error = max(
        abs(b_out[3] - b[3] * b[3]), abs(b_out[9] - b[9] * b[9])
    )

    if finite_difference_max > 2.0e-8:
        raise SystemExit(f"finite difference error too large: {finite_difference_max}")
    if adjoint_residual > 2.0e-12:
        raise SystemExit(f"adjoint residual too large: {adjoint_residual}")
    if callback_error != 0.0:
        raise SystemExit(f"callback error: {callback_error}")

    print("oracle_status: pass")
    print(f"finite_difference_max_error: {finite_difference_max:.16e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.16e}")
    print(f"callback_b4: {b_out[3]:.16e}")
    print(f"callback_b10: {b_out[9]:.16e}")


if __name__ == "__main__":
    main()
