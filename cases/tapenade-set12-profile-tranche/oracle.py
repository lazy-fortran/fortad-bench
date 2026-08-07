"""Independent hand, finite-difference, and adjoint checks for the tranche."""

from __future__ import annotations

import math


def jlb012_primal(x: list[float], n: int = 4) -> float:
    return sum(x[:n])


def jlb012_jvp(xd: list[float], n: int = 4) -> float:
    return sum(xd[:n])


def profile01_primal(a: float, b: float) -> tuple[float, float]:
    return a * a, 2.0 * b


def check() -> None:
    x = [10.0, 2.0, 3.0, 4.0]
    xd = [-0.2, 0.3, 0.5, -0.7]
    assert math.isclose(jlb012_primal(x), 19.0, rel_tol=0.0, abs_tol=1e-14)
    assert math.isclose(jlb012_jvp(xd), -0.1, rel_tol=0.0, abs_tol=1e-14)
    eps = 1e-6
    fd = (jlb012_primal([a + eps * da for a, da in zip(x, xd)]) -
          jlb012_primal([a - eps * da for a, da in zip(x, xd)])) / (2.0 * eps)
    assert math.isclose(fd, jlb012_jvp(xd), rel_tol=0.0, abs_tol=1e-8)

    a, b, ad, bd, seed_a, seed_c = 1.7, 2.4, -0.3, 0.6, 0.8, -0.4
    a_out, c_out = profile01_primal(a, b)
    jvp_a, jvp_c = 2.0 * a * ad, 2.0 * bd
    va, vb = seed_a * 2.0 * a, seed_c * 2.0
    assert math.isclose(a_out, 2.89, rel_tol=0.0, abs_tol=1e-14)
    assert math.isclose(c_out, 4.8, rel_tol=0.0, abs_tol=1e-14)
    assert math.isclose(jvp_a, 2.0 * a * ad, rel_tol=0.0, abs_tol=1e-14)
    assert math.isclose(jvp_c, 2.0 * bd, rel_tol=0.0, abs_tol=1e-14)
    fd_a = (profile01_primal(a + eps * ad, b + eps * bd)[0] -
            profile01_primal(a - eps * ad, b - eps * bd)[0]) / (2.0 * eps)
    fd_c = (profile01_primal(a + eps * ad, b + eps * bd)[1] -
            profile01_primal(a - eps * ad, b - eps * bd)[1]) / (2.0 * eps)
    assert math.isclose(fd_a, jvp_a, rel_tol=0.0, abs_tol=1e-8)
    assert math.isclose(fd_c, jvp_c, rel_tol=0.0, abs_tol=1e-8)
    assert math.isclose(seed_a * jvp_a + seed_c * jvp_c,
                       va * ad + vb * bd, rel_tol=0.0, abs_tol=1e-14)


if __name__ == "__main__":
    check()
    print("oracle_status: pass")
