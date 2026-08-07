#!/usr/bin/env python3
"""Independent p=1 arithmetic oracle for the ala03 wave update."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


DT = 0.00125
PI = 3.141592653589793


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_inventory(source: Path) -> None:
    text = source.read_text(encoding="latin-1").lower()
    compact = re.sub(r"[\s&]+", "", text)
    required = (
        "subroutinewave_resolution(id,p,n_global,n_local,nsteps,c,u_global)",
        "callupdate(id,p,n_global,n_local,nsteps,dt,u1_local,c)",
        "callcollect(id,p,n_global,n_local,nsteps,dt,u1_local,u_global)",
        "$adnocheckpoint",
        "$adcheckpoint-start",
        "callmpi_send",
        "callmpi_recv",
        "0.5d+00*alpha2*u1_local(i_local-1+1)",
        "dudt(x,t)",
        "functionexact(x,t)",
        "functiondudt(x,t)",
    )
    for fragment in required:
        require(fragment in compact, f"exact ala03 source inventory missing {fragment!r}")
    require(
        compact.count("subroutinewave_resolution(id,p,n_global,n_local,nsteps,c,u_global)") == 1,
        "wave_resolution entry point is not unique",
    )
    print("oracle_source_shape: exact MPI wave/checkpoint inventory pass")


def exact_data(x: float, t: float) -> float:
    return math.sin(2.0 * PI * (x - t))


def forcing(x: float, t: float) -> float:
    return -2.0 * PI * math.cos(2.0 * PI * (x - t))


def _validate(c: float, n_global: int, nsteps: int) -> tuple[float, float, float]:
    require(n_global >= 3, "serial oracle needs at least three grid points")
    require(nsteps >= 0, "serial oracle needs a nonnegative step count")
    dx = 1.0 / (n_global - 1)
    alpha = c * DT / dx
    require(abs(alpha) < 1.0, "oracle sample is outside the source stability condition")
    return dx, alpha, alpha * alpha


def wave_primal(c: float, n_global: int, nsteps: int) -> list[float]:
    """Model update/collect for one rank, without importing the source."""

    _, _, alpha2 = _validate(c, n_global, nsteps)
    u0 = [exact_data(i / (n_global - 1), 0.0) for i in range(n_global)]
    u1 = u0.copy()
    for step in range(1, nsteps + 1):
        t = DT * step
        u2 = [0.0] * n_global
        u2[0] = exact_data(0.0, t)
        u2[-1] = exact_data(1.0, t)
        for i in range(1, n_global - 1):
            if step == 1:
                u2[i] = (
                    0.5 * alpha2 * u1[i - 1]
                    + (1.0 - alpha2) * u1[i]
                    + 0.5 * alpha2 * u1[i + 1]
                    + DT * forcing(i / (n_global - 1), t)
                )
            else:
                u2[i] = (
                    alpha2 * u1[i - 1]
                    + 2.0 * (1.0 - alpha2) * u1[i]
                    + alpha2 * u1[i + 1]
                    - u0[i]
                )
        u0, u1 = u1, u2
    return u1


def wave_jvp(c: float, dc: float, n_global: int, nsteps: int) -> list[float]:
    """Hand-propagate d(update)/d(c) for the same finite recurrence."""

    dx, alpha, alpha2 = _validate(c, n_global, nsteps)
    dalpha = DT / dx * dc
    dalpha2 = 2.0 * alpha * dalpha
    u0 = [exact_data(i / (n_global - 1), 0.0) for i in range(n_global)]
    u1 = u0.copy()
    d0 = [0.0] * n_global
    d1 = [0.0] * n_global
    for step in range(1, nsteps + 1):
        t = DT * step
        u2 = [0.0] * n_global
        d2 = [0.0] * n_global
        u2[0] = exact_data(0.0, t)
        u2[-1] = exact_data(1.0, t)
        for i in range(1, n_global - 1):
            if step == 1:
                u2[i] = (
                    0.5 * alpha2 * u1[i - 1]
                    + (1.0 - alpha2) * u1[i]
                    + 0.5 * alpha2 * u1[i + 1]
                    + DT * forcing(i / (n_global - 1), t)
                )
                d2[i] = (
                    0.5 * (dalpha2 * u1[i - 1] + alpha2 * d1[i - 1])
                    - dalpha2 * u1[i]
                    + (1.0 - alpha2) * d1[i]
                    + 0.5 * (dalpha2 * u1[i + 1] + alpha2 * d1[i + 1])
                )
            else:
                u2[i] = (
                    alpha2 * u1[i - 1]
                    + 2.0 * (1.0 - alpha2) * u1[i]
                    + alpha2 * u1[i + 1]
                    - u0[i]
                )
                d2[i] = (
                    dalpha2 * u1[i - 1]
                    + alpha2 * d1[i - 1]
                    - 2.0 * dalpha2 * u1[i]
                    + 2.0 * (1.0 - alpha2) * d1[i]
                    + dalpha2 * u1[i + 1]
                    + alpha2 * d1[i + 1]
                    - d0[i]
                )
        u0, u1 = u1, u2
        d0, d1 = d1, d2
    return d1


def wave_vjp(c: float, seed: list[float], n_global: int, nsteps: int) -> float:
    """Reverse the serial recurrence and return the cotangent for c."""

    dx, alpha, alpha2 = _validate(c, n_global, nsteps)
    dalpha2_dc = 2.0 * alpha * (DT / dx)
    states: list[tuple[list[float], list[float]]] = []
    u0 = [exact_data(i / (n_global - 1), 0.0) for i in range(n_global)]
    u1 = u0.copy()
    for step in range(1, nsteps + 1):
        t = DT * step
        u2 = [0.0] * n_global
        u2[0] = exact_data(0.0, t)
        u2[-1] = exact_data(1.0, t)
        for i in range(1, n_global - 1):
            if step == 1:
                u2[i] = (
                    0.5 * alpha2 * u1[i - 1]
                    + (1.0 - alpha2) * u1[i]
                    + 0.5 * alpha2 * u1[i + 1]
                    + DT * forcing(i / (n_global - 1), t)
                )
            else:
                u2[i] = (
                    alpha2 * u1[i - 1]
                    + 2.0 * (1.0 - alpha2) * u1[i]
                    + alpha2 * u1[i + 1]
                    - u0[i]
                )
        states.append((u0, u1))
        u0, u1 = u1, u2

    bar_u0 = [0.0] * n_global
    bar_u1 = seed.copy()
    cbar = 0.0
    for step in range(nsteps, 0, -1):
        old_u0, old_u1 = states[step - 1]
        next_bar_u0 = [0.0] * n_global
        next_bar_u1 = bar_u0.copy()
        for i in range(1, n_global - 1):
            adj = bar_u1[i]
            if step == 1:
                cbar += adj * dalpha2_dc * (
                    0.5 * old_u1[i - 1] - old_u1[i] + 0.5 * old_u1[i + 1]
                )
                next_bar_u1[i - 1] += adj * 0.5 * alpha2
                next_bar_u1[i] += adj * (1.0 - alpha2)
                next_bar_u1[i + 1] += adj * 0.5 * alpha2
            else:
                cbar += adj * dalpha2_dc * (
                    old_u1[i - 1] - 2.0 * old_u1[i] + old_u1[i + 1]
                )
                next_bar_u0[i] -= adj
                next_bar_u1[i - 1] += adj * alpha2
                next_bar_u1[i] += adj * 2.0 * (1.0 - alpha2)
                next_bar_u1[i + 1] += adj * alpha2
        bar_u0, bar_u1 = next_bar_u0, next_bar_u1
    return cbar


def semantic_checks() -> None:
    c, dc, n_global, nsteps = 0.73, -0.41, 9, 5
    primal = wave_primal(c, n_global, nsteps)
    require(all(math.isfinite(value) for value in primal), "serial wave primal is not finite")
    require(math.isclose(primal[0], exact_data(0.0, DT * nsteps), abs_tol=1.0e-14),
            "left boundary does not preserve exact source data")
    print("oracle_primal: serial p=1 wave recurrence and exact boundaries pass")

    analytic = wave_jvp(c, dc, n_global, nsteps)
    h = 1.0e-6
    plus = wave_primal(c + h * dc, n_global, nsteps)
    minus = wave_primal(c - h * dc, n_global, nsteps)
    finite_difference = [(a - b) / (2.0 * h) for a, b in zip(plus, minus)]
    jvp_error = max(abs(a - b) for a, b in zip(analytic, finite_difference))
    require(jvp_error < 2.0e-9, f"JVP central-difference mismatch: {jvp_error}")
    print(f"oracle_jvp: hand recurrence agrees with central difference max_error={jvp_error:.3e}")

    seed = [math.sin(0.3 * (i + 1)) for i in range(n_global)]
    gradient = wave_vjp(c, seed, n_global, nsteps)
    lhs = sum(a * b for a, b in zip(seed, analytic))
    rhs = gradient * dc
    require(math.isclose(lhs, rhs, rel_tol=0.0, abs_tol=2.0e-11),
            f"VJP dot-product mismatch: {lhs} != {rhs}")
    print(f"oracle_vjp: hand reverse recurrence passes dot product residual={abs(lhs-rhs):.3e}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?", type=Path)
    source = parser.parse_args().source
    if source is not None:
        source_inventory(source.resolve())
    semantic_checks()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
