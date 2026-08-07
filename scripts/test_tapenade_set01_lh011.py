#!/usr/bin/env python3
"""Contract checks for the set01/lh011 exact-source refusal evidence."""

import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "cases/tapenade-set01/tranche-q-lh011-manifest.toml"
RESULT = ROOT / "results/tapenade_set01_lh011_refusal_validation.txt"
HAND = ROOT / "cases/tapenade-set01/hand_derivative_lh011.f90"
HARNESS = ROOT / "harness/bench_tapenade_set01_lh011.f90"


class Lh011RefusalEvidenceTests(unittest.TestCase):
    def test_manifest_records_refusal_and_pins(self):
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        case = manifest["case"][0]
        self.assertEqual(manifest["upstream_revision"],
                         "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["baseline_fortad_commit"],
                         "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(case["classification"], "expected-refusal")
        self.assertEqual(case["ported_entry_point"], "none")
        self.assertEqual(case["expected_diagnostic"],
                         "fortad: unsupported statement at line 6")

    def test_report_records_independent_refusal_evidence(self):
        report = RESULT.read_text()
        for marker in (
            "upstream_program_compile_status: 0",
            "upstream_program_b_compile_status: 1",
            "tapenade_parser_strict_compile_status: 0",
            "tapenade_forward_strict_compile_status: 0",
            "tapenade_reverse_strict_compile_status: 1",
            "fortad_forward_diagnostic: fortad: unsupported statement at line 6",
            "fortad_reverse_diagnostic: fortad: unsupported statement at line 6",
            "oracle_status: pass",
            "refusal_oracle_status: pass",
        ):
            self.assertIn(marker, report)

    def test_oracle_contains_hand_numerical_checks(self):
        hand = HAND.read_text()
        harness = HARNESS.read_text()
        self.assertIn("subroutine hand_jvp", hand)
        self.assertIn("subroutine hand_vjp", hand)
        self.assertIn("bounded_model", hand)
        self.assertIn("finite_difference = (plus - minus)", harness)
        self.assertIn("dot_product(vjp, direction)", harness)
        self.assertIn('"oracle_status: pass"', harness)


if __name__ == "__main__":
    unittest.main()
