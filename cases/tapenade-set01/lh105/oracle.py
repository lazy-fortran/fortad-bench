#!/usr/bin/env python3
"""Independent behavioral oracle for the exact lh105 indexed updates."""

from __future__ import annotations

import math
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"lh105 oracle failure: {message}")


def primal(values: list[float], scale: float, index: int) -> tuple[list[float], int]:
    """Evaluate the exact real-valued operations with a discrete index."""
    result = list(values)
    result[index - 1] += 2.0
    doubled = 2 * index
    result[doubled - 1] = scale * result[doubled - 1]
    return result, doubled


def jvp(
    values: list[float], scale: float, index: int,
    value_direction: list[float], scale_direction: float,
) -> list[float]:
    result = list(value_direction)
    after_first = list(values)
    after_first[index - 1] += 2.0
    doubled = 2 * index
    result[doubled - 1] = (
        scale_direction * after_first[doubled - 1]
        + scale * value_direction[doubled - 1]
    )
    return result


def vjp(values: list[float], scale: float, index: int,
        output_seed: list[float]) -> tuple[list[float], float]:
    after_first = list(values)
    after_first[index - 1] += 2.0
    doubled = 2 * index
    value_gradient = list(output_seed)
    value_gradient[doubled - 1] *= scale
    scale_gradient = after_first[doubled - 1] * output_seed[doubled - 1]
    return value_gradient, scale_gradient


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: oracle.py <upstream-case-directory>")
    source = Path(sys.argv[1]) / "program.f"
    text = source.read_text(encoding="utf-8")
    normalized = " ".join(text.lower().split())
    for fragment in (
        "subroutine top(a,b,i)",
        "a(i) = a(i) + 2",
        "i = 2*i",
        "a(i) = b*a(i)",
    ):
        if fragment not in normalized:
            fail(f"exact source lost operation {fragment!r}")
    print("oracle_source_inventory: pass")

    values = [0.35 * (position + 1) - 0.2 for position in range(10)]
    scale = -0.7
    index = 2
    direction = [(-1.0) ** position * (0.11 + 0.03 * position)
                 for position in range(10)]
    scale_direction = 0.23
    step = 1.0e-6
    plus, _ = primal(
        [value + step * delta for value, delta in zip(values, direction)],
        scale + step * scale_direction,
        index,
    )
    minus, _ = primal(
        [value - step * delta for value, delta in zip(values, direction)],
        scale - step * scale_direction,
        index,
    )
    finite_difference = [(upper - lower) / (2.0 * step)
                         for upper, lower in zip(plus, minus)]
    analytic = jvp(values, scale, index, direction, scale_direction)
    jvp_residual = max(abs(estimate - exact)
                       for estimate, exact in zip(finite_difference, analytic))
    if not math.isclose(jvp_residual, 0.0, abs_tol=2.0e-8):
        fail(f"JVP central-difference residual {jvp_residual}")
    print(f"oracle_jvp_finite_difference: pass residual={jvp_residual:.6e}")

    output_seed = [0.07 * (position + 1) for position in range(10)]
    value_gradient, scale_gradient = vjp(values, scale, index, output_seed)
    left = sum(seed * tangent for seed, tangent in zip(output_seed, analytic))
    right = (sum(gradient * delta
                 for gradient, delta in zip(value_gradient, direction))
             + scale_gradient * scale_direction)
    adjoint_residual = abs(left - right)
    if not math.isclose(adjoint_residual, 0.0, abs_tol=2.0e-12):
        fail(f"VJP adjoint residual {adjoint_residual}")
    print(f"oracle_vjp_adjoint_identity: pass residual={adjoint_residual:.6e}")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
