#!/usr/bin/env python3
"""Three independent behavioral contracts for the ala02 arithmetic boundary."""

from __future__ import annotations

import math
import sys
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
sys.path.insert(0, str(CASE))
import oracle  # noqa: E402


class Ala02ContractTests(unittest.TestCase):
    def test_primal_fixed_point_oracle(self) -> None:
        value, iterations = oracle.root_value(1.0)
        self.assertEqual(iterations, 20)
        self.assertTrue(math.isfinite(value))
        self.assertAlmostEqual(value, 1.0000025309070517, places=12)

    def test_jvp_matches_independent_central_difference(self) -> None:
        for x, dx in ((0.8, 0.2), (1.0, -0.3), (1.2, 0.4)):
            eps = 1.0e-6
            finite_difference = (
                oracle.root_value(x + eps)[0] - oracle.root_value(x - eps)[0]
            ) / (2.0 * eps)
            self.assertLess(
                abs(finite_difference - oracle.root_jvp(x, dx) / dx),
                3.0e-7,
            )

    def test_vjp_satisfies_independent_adjoint_identity(self) -> None:
        for x, dx, seed in ((0.8, 0.2, 0.6), (1.0, -0.3, -1.2), (1.2, 0.4, 2.5)):
            lhs = seed * oracle.root_jvp(x, dx)
            rhs = oracle.root_vjp(x, seed) * dx
            self.assertLess(abs(lhs - rhs), 3.0e-7)


if __name__ == "__main__":
    unittest.main(verbosity=2)
