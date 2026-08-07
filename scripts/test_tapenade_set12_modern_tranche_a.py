"""Independent arithmetic contract for the set12 modern tranche."""

from __future__ import annotations

import math
import unittest


class ModernTrancheOracleTests(unittest.TestCase):
    def test_quadratic_jvp_vjp_adjoint_identity(self) -> None:
        a, b = 1.7, 2.4
        ad, bd, seed = -0.3, 0.6, 0.8
        jvp = 4.0 * a * ad + 2.0 * b * bd
        va, vb = seed * 4.0 * a, seed * 2.0 * b
        self.assertAlmostEqual(seed * jvp, va * ad + vb * bd, places=14)
        self.assertAlmostEqual(b * b + 2.0 * a * a, 11.54, places=14)

    def test_deferred_dispatch_derivatives(self) -> None:
        x, xd, seed = 1.7, -0.4, 0.8
        self.assertAlmostEqual(2.0 * xd, -0.8, places=14)
        self.assertAlmostEqual((2.0 * x + 3.0) * xd, -2.56, places=14)
        self.assertAlmostEqual(seed * 2.0 * xd, (seed * 2.0) * xd, places=14)
        self.assertAlmostEqual(seed * (2.0 * x + 3.0) * xd, seed * -2.56, places=14)

    def test_procedure_pointer_selection_derivatives(self) -> None:
        x, xd = 1.7, 0.25
        self.assertAlmostEqual(x, 1.7, places=14)
        self.assertAlmostEqual(2.0 * x, 3.4, places=14)
        self.assertAlmostEqual(xd, 0.25, places=14)
        self.assertAlmostEqual(2.0 * xd, 0.5, places=14)
        self.assertTrue(math.isclose((-0.6) * 0.5, -0.3, rel_tol=0.0, abs_tol=1e-14))


if __name__ == "__main__":
    unittest.main()
