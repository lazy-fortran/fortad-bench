#!/usr/bin/env python3
"""Independent JVP/VJP/finite-difference oracle for bounded lh060."""

from __future__ import annotations

import math


def primal(q: tuple[float, ...], neq: int = 2) -> tuple[float, float, float]:
    y, savf, tn, c3, c4 = q
    savf = savf + c3 * tn + 0.5 * y + float(neq)
    tn = tn + 0.1 * c3 * y
    y = y + c4 * savf + tn + 0.25 * c3
    tn = tn + 0.05 * c4 * savf
    savf = savf + c3 * tn + 0.5 * y + float(neq)
    tn = tn + 0.1 * c3 * y
    return y, savf, tn


def hand_jvp(q: tuple[float, ...], dq: tuple[float, ...], neq: int = 2):
    y, savf, tn, c3, c4 = q
    yd, savfd, tnd, c3d, c4d = dq

    s1 = savf + c3 * tn + 0.5 * y + float(neq)
    s1d = savfd + c3d * tn + c3 * tnd + 0.5 * yd
    t1 = tn + 0.1 * c3 * y
    t1d = tnd + 0.1 * (c3d * y + c3 * yd)
    y1 = y + c4 * s1 + t1 + 0.25 * c3
    y1d = yd + c4d * s1 + c4 * s1d + t1d + 0.25 * c3d
    t1 = t1 + 0.05 * c4 * s1
    t1d = t1d + 0.05 * (c4d * s1 + c4 * s1d)
    s2 = s1 + c3 * t1 + 0.5 * y1 + float(neq)
    s2d = s1d + c3d * t1 + c3 * t1d + 0.5 * y1d
    t2 = t1 + 0.1 * c3 * y1
    t2d = t1d + 0.1 * (c3d * y1 + c3 * y1d)
    return (y1d, s2d, t2d), (y1, s2, t2)


def vjp(q: tuple[float, ...], seed: tuple[float, float, float], neq: int = 2):
    """Reverse product from a hand-derived reverse sweep."""
    y, savf, tn, c3, c4 = q
    # Forward intermediates.
    s1 = savf + c3 * tn + 0.5 * y + float(neq)
    t1 = tn + 0.1 * c3 * y
    y1 = y + c4 * s1 + t1 + 0.25 * c3
    t2 = t1 + 0.05 * c4 * s1
    s2 = s1 + c3 * t2 + 0.5 * y1 + float(neq)
    y1b, s2b, t3b = seed
    yb = 0.0
    sb = s2b
    tb = t3b
    # Reverse final tn = t2 + .1*c3*y1, then savf=s2, y=y1.
    c3b = 0.1 * y1 * tb
    y1b += 0.1 * c3 * tb
    t2b = tb
    s1b = sb
    c3b += t2 * sb
    t2b += c3 * sb
    y1b += 0.5 * sb

    # Reverse t2 = t1 + .05*c4*s1.
    t1b = t2b
    c4b = 0.05 * s1 * t2b
    s1b += 0.05 * c4 * t2b

    # Reverse y1 = y + c4*s1 + t1 + .25*c3.
    yb += y1b
    c4b += s1 * y1b
    s1b += c4 * y1b
    t1b += y1b
    c3b += 0.25 * y1b

    # Reverse t1 = tn + .1*c3*y.
    tnb = t1b
    c3b += 0.1 * y * t1b
    yb += 0.1 * c3 * t1b
    # Reverse s1 = savf + c3*tn + .5*y.
    savfb = s1b
    c3b += tn * s1b
    tnb += c3 * s1b
    yb += 0.5 * s1b
    return (yb, savfb, tnb, c3b, c4b)


def main() -> int:
    q = (0.7, -0.4, 0.25, 1.3, -0.6)
    dq = (0.11, -0.07, 0.05, -0.09, 0.13)
    (jvp_y, jvp_s, jvp_t), _ = hand_jvp(q, dq)
    h = 1.0e-6
    plus = primal(tuple(a + h * b for a, b in zip(q, dq)))
    minus = primal(tuple(a - h * b for a, b in zip(q, dq)))
    finite = tuple((a - b) / (2.0 * h) for a, b in zip(plus, minus))
    fd_error = max(abs(a - b) for a, b in zip((jvp_y, jvp_s, jvp_t), finite))
    if not math.isfinite(fd_error) or fd_error > 2.0e-8:
        raise SystemExit(f"finite-difference mismatch: {fd_error}")

    seed = (0.4, -0.8, 0.6)
    reverse = vjp(q, seed)
    lhs = sum(a * b for a, b in zip((jvp_y, jvp_s, jvp_t), seed))
    rhs = sum(a * b for a, b in zip(reverse, dq))
    adjoint_error = abs(lhs - rhs)
    if not math.isfinite(adjoint_error) or adjoint_error > 2.0e-12:
        raise SystemExit(f"adjoint mismatch: {adjoint_error}")
    print(f"oracle_status: pass max_fd_error={fd_error:.3e} adjoint_error={adjoint_error:.3e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
