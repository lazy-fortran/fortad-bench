#!/usr/bin/env python3
"""Independent oracle for v385's local arithmetic after MPI_TEST succeeds.

This deliberately does not implement MPI or claim a port.  The source fills
buf with 1..10 and then computes resultat(i)=buf(i)**2.  The checks below use
only that mathematical map: central finite differences check its tangent, and
the dot-product identity checks the corresponding reverse weights.
"""

from __future__ import annotations

import math


def square_map(values: list[float]) -> list[float]:
    return [value * value for value in values]


def main() -> None:
    buf = [float(index) for index in range(1, 11)]
    direction = [(-1.0) ** index for index in range(1, 11)]
    cotangent = [0.25 + 0.1 * index for index in range(1, 11)]
    tangent = [2.0 * value * delta for value, delta in zip(buf, direction)]
    reverse = [2.0 * value * weight for value, weight in zip(buf, cotangent)]

    epsilon = 1.0e-5
    plus = square_map([value + epsilon * delta for value, delta in zip(buf, direction)])
    minus = square_map([value - epsilon * delta for value, delta in zip(buf, direction)])
    finite_difference = [
        (up - down) / (2.0 * epsilon) for up, down in zip(plus, minus)
    ]
    max_fd_error = max(
        abs(actual - expected) for actual, expected in zip(finite_difference, tangent)
    )
    lhs = math.fsum(value * weight for value, weight in zip(tangent, cotangent))
    rhs = math.fsum(delta * weight for delta, weight in zip(direction, reverse))
    dot_error = abs(lhs - rhs)
    if max_fd_error >= 1.0e-8 or dot_error >= 1.0e-12:
        raise SystemExit(
            f"oracle failed: max_fd_error={max_fd_error} dot_error={dot_error}"
        )
    print(
        "oracle_status: pass local-square-map "
        f"max_fd_error={max_fd_error:.3e} dot_error={dot_error:.3e}"
    )


if __name__ == "__main__":
    main()
