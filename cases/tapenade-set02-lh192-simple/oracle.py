#!/usr/bin/env python3
"""Independent scalar oracle for the observable lh192 dataflow."""
from __future__ import annotations


def primal(x: float, a: float, b: float, c: float) -> tuple[float, float, float]:
    y = a * b
    x_out = x * y * c
    checkpoint_value = x * 2.5
    return x_out, y, checkpoint_value


def jvp(x: float, a: float, b: float, c: float, dx: float, da: float, db: float, dc: float):
    y = a * b
    dy = da * b + a * db
    return dx * y * c + x * dy * c + x * y * dc, dy, dx * 2.5


def main() -> None:
    eps = 1.0e-6
    point = (1.7, 2.0, -0.25, 0.8)
    direction = (0.3, -0.4, 0.2, -0.1)
    base = primal(*point)
    shifted = primal(*(p + eps * d for p, d in zip(point, direction)))
    finite = tuple((a - b) / eps for a, b in zip(shifted, base))
    hand = jvp(*point, *direction)
    assert max(abs(a - b) for a, b in zip(finite, hand)) < 5.0e-5
    assert base[1] == point[1] * point[2]
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
