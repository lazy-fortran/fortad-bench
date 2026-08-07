"""Contract checks for the set02 lh150 evidence tranche."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh150EvidenceTests(unittest.TestCase):
    def test_report_records_independent_gates(self):
        report = (ROOT / "results/tapenade_set02_lh150_validation.txt").read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "upstream_exact_source_compile_statuses:",
            "fortad_transform_compile_statuses:",
            "independent_oracle: closed-form JVP/VJP",
        ):
            self.assertIn(marker, report)

    def test_manifest_is_pinned_and_bounded(self):
        manifest = (ROOT / "cases/tapenade-set02/tranche-a-lh150-manifest.toml").read_text()
        self.assertIn('upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"', manifest)
        self.assertIn('upstream_entry = "top(xx)"', manifest)
        self.assertIn('independent = ["x"]', manifest)


if __name__ == "__main__":
    unittest.main()
