#!/usr/bin/env python3
"""Independent arithmetic oracle for the live equations in v417.

This model deliberately does not parse or execute the Fortran source, Tapenade,
or FortAD.  It checks the live nonzero-domain equations with a hand JVP, a
central-difference sweep, and the matching hand VJP.
"""

from __future__ import annotations

import math


G = -9.81


def primal(x: list[float]) -> list[float]:
    volumes = x[0:3]
    densities = x[3:6]
    force = x[6]
    acceleration = x[7]
    masses = [rho * volume * acceleration for rho, volume in zip(densities, volumes)]
    acc = [force / mass for mass in masses]
    force_out = masses[-1] * (G + acceleration + sum(acc))
    return [force_out, *acc, 0.0]


def jvp(x: list[float], dx: list[float]) -> list[float]:
    volumes = x[0:3]
    densities = x[3:6]
    force = x[6]
    acceleration = x[7]
    dvolumes = dx[0:3]
    ddensities = dx[3:6]
    dforce = dx[6]
    dacceleration = dx[7]
    masses = [rho * volume * acceleration for rho, volume in zip(densities, volumes)]
    dmasses = [
        acceleration * (rho * dvolume + volume * drho)
        + rho * volume * dacceleration
        for rho, volume, dvolume, drho in zip(
            densities, volumes, dvolumes, ddensities
        )
    ]
    acc = [force / mass for mass in masses]
    dacc = [
        dforce / mass - force * dmass / mass**2
        for mass, dmass in zip(masses, dmasses)
    ]
    total = G + acceleration + sum(acc)
    dforce_out = dmasses[-1] * total + masses[-1] * (
        dacceleration + sum(dacc)
    )
    return [dforce_out, *dacc, 0.0]


def vjp(x: list[float], cotangent: list[float]) -> list[float]:
    volumes = x[0:3]
    densities = x[3:6]
    force = x[6]
    acceleration = x[7]
    y_force = cotangent[0]
    y_acc = cotangent[1:4]
    masses = [rho * volume * acceleration for rho, volume in zip(densities, volumes)]
    acc = [force / mass for mass in masses]
    total = G + acceleration + sum(acc)
    q = [y_acc_i + y_force * masses[-1] for y_acc_i in y_acc]
    dmass = [
        (y_force * total if index == len(masses) - 1 else 0.0)
        - q_i * force / mass**2
        for index, (q_i, mass) in enumerate(zip(q, masses))
    ]
    gradient_volumes = [
        gm * rho * acceleration for gm, rho in zip(dmass, densities)
    ]
    gradient_densities = [
        gm * volume * acceleration for gm, volume in zip(dmass, volumes)
    ]
    gradient_force = sum(q_i / mass for q_i, mass in zip(q, masses))
    gradient_acceleration = sum(
        gm * rho * volume for gm, rho, volume in zip(dmass, densities, volumes)
    ) + y_force * masses[-1]
    return [
        *gradient_volumes,
        *gradient_densities,
        gradient_force,
        gradient_acceleration,
    ]


def main() -> None:
    x = [1.1, 1.4, 1.8, 2.0, 2.5, 3.0, 5.0, 0.75]
    dx = [0.1, -0.2, 0.05, 0.2, -0.1, 0.15, 0.4, -0.07]
    cotangent = [0.7, -0.4, 0.2, 0.9, 0.0]
    epsilon = 1.0e-6
    plus = primal([value + epsilon * direction for value, direction in zip(x, dx)])
    minus = primal([value - epsilon * direction for value, direction in zip(x, dx)])
    finite_difference = [
        (high - low) / (2.0 * epsilon) for high, low in zip(plus, minus)
    ]
    tangent = jvp(x, dx)
    finite_difference_error = max(
        abs(estimate - exact) for estimate, exact in zip(finite_difference, tangent)
    )
    adjoint_left = sum(weight * value for weight, value in zip(cotangent, tangent))
    adjoint_right = sum(
        value * direction for value, direction in zip(vjp(x, cotangent), dx)
    )
    adjoint_residual = abs(adjoint_left - adjoint_right)
    assert math.isfinite(finite_difference_error)
    assert math.isfinite(adjoint_residual)
    assert finite_difference_error < 1.0e-7, finite_difference_error
    assert adjoint_residual < 1.0e-12, adjoint_residual
    print("oracle_status: pass")
    print(f"finite_difference_max_error: {finite_difference_error:.16e}")
    print(f"adjoint_identity_residual: {adjoint_residual:.16e}")
    print(f"sample_force: {primal(x)[0]:.16e}")


if __name__ == "__main__":
    main()
