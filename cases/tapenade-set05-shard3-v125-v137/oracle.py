"""Independent hand, finite-difference, and adjoint checks for v125/v137."""

from __future__ import annotations


def primal_v137(x: float, y: float) -> float:
    return x * y + x


def jvp_v137(x: float, y: float, dx: float, dy: float) -> float:
    return (y + 1.0) * dx + x * dy


def vjp_v137(x: float, y: float, seed: float) -> tuple[float, float]:
    return seed * (y + 1.0), seed * x


def primal_v125(x1: float, x2: float, y1: float, y2: float) -> float:
    return (x1 - x2) * (y1 - y2)


def jvp_v125(
    x1: float, x2: float, y1: float, y2: float,
    dx1: float, dx2: float, dy1: float, dy2: float,
) -> float:
    return (dx1 - dx2) * (y1 - y2) + (x1 - x2) * (dy1 - dy2)


def vjp_v125(
    x1: float, x2: float, y1: float, y2: float, seed: float
) -> tuple[float, float, float, float]:
    return (
        seed * (y1 - y2),
        -seed * (y1 - y2),
        seed * (x1 - x2),
        -seed * (x1 - x2),
    )
