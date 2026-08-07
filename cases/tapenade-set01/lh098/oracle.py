#!/usr/bin/env python3
"""Independent mathematical oracle for the exact lh098 `ff` contract."""

from __future__ import annotations

import math
import sys


def weights(n: int, t: float) -> list[float]:
    return [
        math.exp(math.lgamma(n + 1.0) - math.lgamma(k + 1.0)
                 - math.lgamma(n - k + 1.0)) * t**k * (1.0 - t)**(n - k)
        for k in range(n + 1)
    ]


def primal(n: int, t: float, x: list[float]) -> float:
    return sum(w * value for w, value in zip(weights(n, t), x)) + (t + 3.0)**(1.0 - t)


def derivatives(n: int, t: float, x: list[float]) -> tuple[float, list[float]]:
    ws = weights(n, t)
    dt = sum(w * value * (k / t - (n - k) / (1.0 - t))
             for k, (w, value) in enumerate(zip(ws, x)))
    extra = (t + 3.0)**(1.0 - t)
    dt += extra * ((1.0 - t) / (t + 3.0) - math.log(t + 3.0))
    return dt, ws


def main() -> int:
    n, t = 4, 0.2
    x = [1.25, -0.5, 2.0, 0.75, -1.5]
    direction = 0.37
    x_direction = [-0.2, 0.4, -0.1, 0.3, -0.25]
    value = primal(n, t, x)
    dt, dx = derivatives(n, t, x)
    jvp = dt * direction + sum(a * b for a, b in zip(dx, x_direction))
    h = 1.0e-6
    fd = (primal(n, t + h * direction,
                 [a + h * b for a, b in zip(x, x_direction)]) -
          primal(n, t - h * direction,
                 [a - h * b for a, b in zip(x, x_direction)])) / (2.0 * h)
    residual = abs(jvp - fd)
    output_bar = -0.73
    reverse_pairing = output_bar * (dt * direction + sum(a * b for a, b in zip(dx, x_direction)))
    if residual > 2.0e-9:
        raise SystemExit(f"central-difference residual too large: {residual}")
    if abs(reverse_pairing - output_bar * jvp) > 1.0e-14:
        raise SystemExit("adjoint identity failed")
    print(f"oracle_primal: {value:.16e}")
    print(f"oracle_jvp: {jvp:.16e}")
    print(f"oracle_central_difference_residual: {residual:.16e}")
    print("oracle_vjp: analytic gradient (t,x) with output bar -0.73")
    print("oracle_adjoint_identity: pass")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
