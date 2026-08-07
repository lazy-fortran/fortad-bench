"""Behavioral and evidence-contract checks for the isolated lh038 case."""

from __future__ import annotations

import math
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


def value(pi: float, x: float) -> float:
    return 11.3 + pi if x > 20.0 else x


def jvp(x: float, dpi: float, dx: float) -> float:
    return dpi if x > 20.0 else dx


class Lh038ContractTests(unittest.TestCase):
    def test_manifest_records_pins_boundary_and_modes(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        case = manifest["case"][0]
        self.assertEqual(case["id"], "lh038")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "db0050259520b618e2a0aeba203c85a7613943b5",
        )
        self.assertEqual(
            case["classification"], "expected-refusal-with-bounded-forward-port"
        )
        self.assertEqual(case["upstream_entry_point"], "top(x)")
        self.assertIn("program_dv.f", case["stored_references"])
        self.assertIn("exact-forward:refused", case["modes"])
        self.assertIn("bounded-reverse:refused", case["modes"])

    def test_result_records_all_engine_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "upstream_exact_source_compile: pass",
            "upstream_stored_references_strict_compile:",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_generated_strict_compile: parser=pass tangent=pass reverse=pass",
            "fortad_exact_result: expected-refusal",
            "fortad_port_result: forward=pass reverse=expected-refusal-generated-compile",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        self.assertIn("unsupported statement at line 3", report)
        self.assertIn("Duplicate symbol", report)
        self.assertRegex(report, r"fd_errors:\s+[0-9.eE+-]+")
        self.assertRegex(report, r"adjoint_residual:\s+[0-9.eE+-]+")

    def test_independent_closed_form_and_finite_difference(self) -> None:
        for pi, x, dpi, dx, expected in (
            (3.14, 10.0, 0.7, 0.3, 10.0),
            (3.14, 25.0, 0.7, 0.3, 14.44),
        ):
            self.assertAlmostEqual(value(pi, x), expected, places=6)
            hand = jvp(x, dpi, dx)
            for step in (1.0e-3, 1.0e-4, 1.0e-5):
                finite_difference = (
                    value(pi + step * dpi, x + step * dx)
                    - value(pi - step * dpi, x - step * dx)
                ) / (2.0 * step)
                self.assertLess(abs(finite_difference - hand), 1.0e-6)
            self.assertTrue(math.isfinite(expected))


if __name__ == "__main__":
    unittest.main()
