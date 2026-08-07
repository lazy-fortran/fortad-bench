#!/usr/bin/env python3
"""Independent semantic oracle for the ala01 fixed-point procedure.

This model is deliberately separate from Tapenade and FortAD. It encodes the
mathematics of ROOT's assignment sequence, then checks primal, tangent, and
adjoint identities without invoking either source transformer or generated
code.
"""

from __future__ import annotations

import math


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def primal(x: float, initial: float) -> tuple[float, list[float], int]:
    z = initial
    previous = z + 1.0
    states = [z]
    iterations = 0
    while (z - previous) ** 2 >= 1.0e-10:
        previous = z
        z = math.sin(x * z * z)
        states.append(z)
        iterations += 1
        require(iterations < 1000, "fixed-point model did not terminate")
    return x * z, states, iterations


def jvp(
    x: float, initial: float, dx: float, dinitial: float
) -> tuple[float, int]:
    z = initial
    zd = dinitial
    previous = z + 1.0
    iterations = 0
    while (z - previous) ** 2 >= 1.0e-10:
        previous = z
        zd = math.cos(x * z * z) * (z * z * dx + 2.0 * x * z * zd)
        z = math.sin(x * z * z)
        iterations += 1
        require(iterations < 1000, "fixed-point tangent model did not terminate")
    return z * dx + x * zd, iterations


def vjp(x: float, initial: float) -> tuple[float, float, int]:
    _, states, iterations = primal(x, initial)
    adjoint_x = states[-1]
    adjoint_z = x
    for z in reversed(states[:-1]):
        adjoint_u = adjoint_z * math.cos(x * z * z)
        adjoint_x += adjoint_u * z * z
        adjoint_z = adjoint_u * (2.0 * x * z)
    return adjoint_x, adjoint_z, iterations


def main() -> int:
    x = 0.5
    initial = 2.0
    value, _, iterations = primal(x, initial)
    require(iterations == 6, f"unexpected iteration count: {iterations}")
    require(
        math.isclose(value, 6.962800215095558e-12, rel_tol=0.0, abs_tol=1.0e-20),
        f"unexpected primal value: {value}",
    )
    print("oracle_primal: value=6.962800215095558e-12 iterations=6")

    dx = 0.37
    dinitial = -0.42
    analytic_jvp, jvp_iterations = jvp(x, initial, dx, dinitial)
    require(jvp_iterations == iterations, "tangent took a different path")
    h = 1.0e-5
    plus = primal(x + h * dx, initial + h * dinitial)[0]
    minus = primal(x - h * dx, initial - h * dinitial)[0]
    finite_difference = (plus - minus) / (2.0 * h)
    require(
        math.isclose(analytic_jvp, finite_difference, rel_tol=2.0e-7, abs_tol=1.0e-17),
        f"JVP finite-difference mismatch: {analytic_jvp} != {finite_difference}",
    )
    print("oracle_jvp_finite_difference: pass")

    gradient_x, gradient_initial, vjp_iterations = vjp(x, initial)
    require(vjp_iterations == iterations, "adjoint took a different path")
    tangent_dot = analytic_jvp
    adjoint_dot = gradient_x * dx + gradient_initial * dinitial
    require(
        math.isclose(tangent_dot, adjoint_dot, rel_tol=0.0, abs_tol=1.0e-16),
        f"VJP dot-product mismatch: {tangent_dot} != {adjoint_dot}",
    )
    print("oracle_vjp_dot_product: pass")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
