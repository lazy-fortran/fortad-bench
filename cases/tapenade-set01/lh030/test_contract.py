"""Contract and independent numerical checks for the lh030 evidence."""

from __future__ import annotations

import math
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


def value(x1: float, x2: float) -> float:
    f1 = math.exp(x1 * x1)
    f2 = math.exp(x2 * x2)
    a = math.sqrt(f1 + math.sin(x1) / x1)
    b = math.sqrt(f2 - math.sin(x2) / x2)
    return (a - b) / (1.0 + a + b)


def gradient(x1: float, x2: float) -> tuple[float, float]:
    f1 = math.exp(x1 * x1)
    f2 = math.exp(x2 * x2)
    q1 = math.sin(x1) / x1
    q2 = math.sin(x2) / x2
    a = math.sqrt(f1 + q1)
    b = math.sqrt(f2 - q2)
    da = (2.0 * x1 * f1 + (x1 * math.cos(x1) - math.sin(x1)) / x1**2) / (2.0 * a)
    db = (2.0 * x2 * f2 - (x2 * math.cos(x2) - math.sin(x2)) / x2**2) / (2.0 * b)
    n = a - b
    d = 1.0 + a + b
    return da * (d - n) / d**2, -db * (d + n) / d**2


class Lh030ContractTests(unittest.TestCase):
    def test_manifest_records_pins_and_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        case = manifest["case"][0]
        self.assertEqual(case["id"], "lh030")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "db0050259520b618e2a0aeba203c85a7613943b5",
        )
        self.assertEqual(
            case["classification"],
            "runnable-ported-with-exact-source-fortad-refusal",
        )
        self.assertIn("program_dv.f", case["stored_references"])

    def test_result_records_all_engine_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "upstream_exact_source_compile: pass",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_generated_strict_compile: parser=pass tangent=pass reverse=pass",
            "fortad_exact_result: expected-refusal",
            "fortad_port_result: pass-transform-compile-runtime",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)

    def test_independent_gradient_finite_difference_and_adjoint(self) -> None:
        x1, x2 = 0.55, 0.35
        dx1, dx2 = -0.17, 0.29
        seed = 0.73
        g1, g2 = gradient(x1, x2)
        hand_direction = g1 * dx1 + g2 * dx2
        self.assertTrue(math.isfinite(value(x1, x2)))
        self.assertAlmostEqual(
            seed * hand_direction,
            (seed * g1) * dx1 + (seed * g2) * dx2,
            places=14,
        )
        errors = []
        for step in (1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5):
            finite_difference = (
                value(x1 + step * dx1, x2 + step * dx2)
                - value(x1 - step * dx1, x2 - step * dx2)
            ) / (2.0 * step)
            errors.append(abs(finite_difference - hand_direction))
        self.assertLess(min(errors), 2.0e-9)


if __name__ == "__main__":
    unittest.main()
