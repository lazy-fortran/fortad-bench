"""Contract checks for the set03 ht09 evidence case."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Ht09EvidenceTests(unittest.TestCase):
    def test_report_records_independent_gates(self):
        report = (ROOT / "results/tapenade_set03_ht09_validation.txt").read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "upstream_exact_source_compile_statuses:",
            "upstream_source_byte_exact: yes",
            "fortad_transform_compile_statuses:",
            "independent_oracle: hand analytic JVP/VJP",
        ):
            self.assertIn(marker, report)

    def test_manifest_and_case_are_pinned(self):
        manifest = (
            ROOT / "cases/tapenade-set03/tranche-p-ht09-manifest.toml"
        ).read_text()
        source = (ROOT / "cases/tapenade-set03/ht09.f90").read_text()
        self.assertIn(
            'upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"',
            manifest,
        )
        self.assertIn('id = "ht09"', manifest)
        self.assertIn('independent = ["x"]', manifest)
        self.assertIn("y = sqrt(abs(x))", source)


if __name__ == "__main__":
    unittest.main()
