"""Contract checks for the set06 v234 evidence tranche."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class V234EvidenceTests(unittest.TestCase):
    def test_report_records_independent_gates(self):
        report = (ROOT / "results/tapenade_set06_v234_validation.txt").read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "upstream_exact_source_compile_statuses:",
            "fortad_transform_compile_statuses:",
            "independent_oracle: hand derivative",
        ):
            self.assertIn(marker, report)

    def test_manifest_is_pinned_and_scoped(self):
        manifest = (ROOT / "cases/tapenade-set06/tranche-a-v234-manifest.toml").read_text()
        self.assertIn('upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"', manifest)
        self.assertIn('id = "v234"', manifest)
        self.assertIn('independent = ["t"]', manifest)


if __name__ == "__main__":
    unittest.main()
