"""Contract checks for the exact-source lh007 refusal record."""

import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh007EvidenceTests(unittest.TestCase):
    def test_manifest_and_result_pin_the_refusal(self):
        with (ROOT / "cases/tapenade-set01/lh007-manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        report = (ROOT / "results/tapenade_set01_lh007_refusal_validation.txt").read_text()
        self.assertEqual(manifest["classification"], "expected-refusal")
        self.assertEqual(manifest["expected_diagnostic"],
                         "fortad: unsupported statement at line 6")
        self.assertIn("required_fortad_commit: db0050259520b618e2a0aeba203c85a7613943b5", report)
        self.assertIn("tapenade_commit: e59864cab441d4175df75383b3ff58c3dcd26df9", report)
        self.assertIn("fortad_exact_result: expected-refusal", report)
        self.assertIn("oracle_status: pass", report)

    def test_harness_exercises_independent_derivative_checks(self):
        harness = (ROOT / "harness/bench_tapenade_set01_lh007.f90").read_text()
        for marker in ("central difference", "adjoint identity",
                       "lh007_jvp_hand", "use lh007_forward"):
            self.assertIn(marker, harness)


if __name__ == "__main__":
    unittest.main()
