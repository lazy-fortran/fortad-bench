#!/usr/bin/env python3
"""Independent numerical oracle for the lh084 primal and reverse recurrence."""

from __future__ import annotations

import math


def primal(base):
    """Source-independent 1-based transcription of flw2d1COL and check."""
    t3, pres, vnocl, g3, g4, rh3, rh4, sq = base
    rh3, rh4 = rh3[:], rh4[:]
    for iseg, (is1, is2) in enumerate(((1, 2), (2, 3))):
        qsor = t3[is1 - 1] * vnocl[iseg][1]
        qsex = t3[is2 - 1] * vnocl[iseg][1]
        dplim = qsor * g4[is1 - 1] + qsex * g4[is2 - 1]
        rh4[is1 - 1] += dplim
        rh4[is2 - 1] -= dplim
        pm = pres[is1 - 1] + pres[is2 - 1]
        dplim = qsor * g3[is1 - 1] + qsex * g3[is2 - 1] + pm * vnocl[iseg][1]
        rh3[is1 - 1] += dplim
        rh3[is2 - 1] -= dplim
        sq += pm * pm
    return rh3, rh4, sq


def jvp(base, direction):
    """Independent dual-number transcription of the same recurrence."""
    t3, pres, vnocl, g3, g4, rh3, rh4, sq = base
    dt3, dpres, dvnocl, dg3, dg4, drh3, drh4, dsq = direction
    rh3, rh4, drh3, drh4 = rh3[:], rh4[:], drh3[:], drh4[:]
    for iseg, (is1, is2) in enumerate(((1, 2), (2, 3))):
        qsor = t3[is1 - 1] * vnocl[iseg][1]
        dqsor = dt3[is1 - 1] * vnocl[iseg][1] + t3[is1 - 1] * dvnocl[iseg][1]
        qsex = t3[is2 - 1] * vnocl[iseg][1]
        dqsex = dt3[is2 - 1] * vnocl[iseg][1] + t3[is2 - 1] * dvnocl[iseg][1]
        dplim = qsor * g4[is1 - 1] + qsex * g4[is2 - 1]
        ddplim = dqsor * g4[is1 - 1] + qsor * dg4[is1 - 1] + dqsex * g4[is2 - 1] + qsex * dg4[is2 - 1]
        rh4[is1 - 1] += dplim
        rh4[is2 - 1] -= dplim
        drh4[is1 - 1] += ddplim
        drh4[is2 - 1] -= ddplim
        pm = pres[is1 - 1] + pres[is2 - 1]
        dpm = dpres[is1 - 1] + dpres[is2 - 1]
        dplim = qsor * g3[is1 - 1] + qsex * g3[is2 - 1] + pm * vnocl[iseg][1]
        ddplim = (dqsor * g3[is1 - 1] + qsor * dg3[is1 - 1] +
                  dqsex * g3[is2 - 1] + qsex * dg3[is2 - 1] +
                  dpm * vnocl[iseg][1] + pm * dvnocl[iseg][1])
        rh3[is1 - 1] += dplim
        rh3[is2 - 1] -= dplim
        drh3[is1 - 1] += ddplim
        drh3[is2 - 1] -= ddplim
        sq += pm * pm
        dsq += 2.0 * pm * dpm
    return (rh3, rh4, sq), (drh3, drh4, dsq)


def reverse_vjp(base, rh3b, rh4b, sqb):
    """Independent reverse recurrence for output seeds rh3, rh4, and sq."""
    t3, pres, vnocl, g3, g4, rh3, rh4, sq = base
    t3b = [0.0] * 3
    presb = [0.0] * 3
    vnoclb = [[0.0, 0.0], [0.0, 0.0]]
    g3b, g4b = [0.0] * 3, [0.0] * 3
    for iseg in range(1, -1, -1):
        is1, is2 = ((1, 2), (2, 3))[iseg]
        pm = pres[is1 - 1] + pres[is2 - 1]
        pmb = 2.0 * pm * sqb
        dplimb = rh3b[is1 - 1] - rh3b[is2 - 1]
        qsex = t3[is2 - 1] * vnocl[iseg][1]
        qsor = t3[is1 - 1] * vnocl[iseg][1]
        qsorb = g3[is1 - 1] * dplimb
        g3b[is1 - 1] += qsor * dplimb
        qsexb = g3[is2 - 1] * dplimb
        g3b[is2 - 1] += qsex * dplimb
        pmb += vnocl[iseg][1] * dplimb
        vnoclb[iseg][1] += pm * dplimb
        presb[is1 - 1] += pmb
        presb[is2 - 1] += pmb
        dplimb = rh4b[is1 - 1] - rh4b[is2 - 1]
        qsorb += g4[is1 - 1] * dplimb
        g4b[is1 - 1] += qsor * dplimb
        qsexb += g4[is2 - 1] * dplimb
        g4b[is2 - 1] += qsex * dplimb
        t3b[is2 - 1] += vnocl[iseg][1] * qsexb
        vnoclb[iseg][1] += t3[is2 - 1] * qsexb + t3[is1 - 1] * qsorb
        t3b[is1 - 1] += vnocl[iseg][1] * qsorb
    return t3b, presb, vnoclb, g3b, g4b, rh3b, rh4b, sqb


def scale_add(base, direction, scale):
    result = []
    for value, delta in zip(base, direction):
        if isinstance(value, list) and value and isinstance(value[0], list):
            result.append([[x + scale * y for x, y in zip(row, drow)] for row, drow in zip(value, delta)])
        elif isinstance(value, list):
            result.append([x + scale * y for x, y in zip(value, delta)])
        else:
            result.append(value + scale * delta)
    return tuple(result)


def dot_inputs(gradient, direction):
    total = 0.0
    for grad, delta in zip(gradient, direction):
        if isinstance(grad, list) and grad and isinstance(grad[0], list):
            total += sum(a * b for row, drow in zip(grad, delta) for a, b in zip(row, drow))
        elif isinstance(grad, list):
            total += sum(a * b for a, b in zip(grad, delta))
        else:
            total += grad * delta
    return total


def main() -> int:
    base = ([0.8, -0.4, 0.6], [1.1, -0.7, 0.3], [[0.2, 0.9], [-0.1, 0.5]], [0.4, -0.6, 0.8], [-0.5, 0.7, 0.2], [-0.2, 0.3, -0.1], [0.4, -0.6, 0.2], 0.15)
    direction = ([0.03, -0.02, 0.01], [0.02, 0.01, -0.03], [[0.01, -0.02], [0.03, 0.04]], [-0.01, 0.04, -0.02], [0.03, -0.02, 0.01], [0.02, 0.01, 0.03], [-0.04, 0.02, 0.01], 0.03)
    value, tangent = jvp(base, direction)
    h = 1.0e-6
    finite_plus = primal(scale_add(base, direction, h))
    finite_minus = primal(scale_add(base, direction, -h))
    finite = ([ (finite_plus[0][i] - finite_minus[0][i]) / (2 * h) for i in range(3)], [ (finite_plus[1][i] - finite_minus[1][i]) / (2 * h) for i in range(3)], (finite_plus[2] - finite_minus[2]) / (2 * h))
    fd_error = max([abs(a - b) for aa, bb in zip(tangent[:2], finite[:2]) for a, b in zip(aa, bb)] + [abs(tangent[2] - finite[2])])
    rh3_seed, rh4_seed, sq_seed = [0.6, -0.2, 0.1], [-0.5, 0.4, -0.3], 0.8
    gradient = reverse_vjp(base, rh3_seed, rh4_seed, sq_seed)
    lhs = sum(a * b for a, b in zip(rh3_seed, tangent[0])) + sum(a * b for a, b in zip(rh4_seed, tangent[1])) + sq_seed * tangent[2]
    adjoint_error = abs(lhs - dot_inputs(gradient, direction))
    if not all(math.isfinite(x) for x in value[0] + value[1] + [value[2]]):
        raise SystemExit("non-finite primal result")
    if fd_error > 1.0e-8 or adjoint_error > 1.0e-12:
        raise SystemExit(f"oracle residual too large: finite_difference={fd_error} adjoint={adjoint_error}")
    print("oracle_status: pass")
    print(f"primal_rh3: {','.join(f'{x:.16e}' for x in value[0])}")
    print(f"primal_rh4: {','.join(f'{x:.16e}' for x in value[1])}")
    print(f"primal_sq: {value[2]:.16e}")
    print(f"finite_difference_max_error: {fd_error:.16e}")
    print(f"adjoint_identity_residual: {adjoint_error:.16e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
