"""Contract checks for the set01 lh086 evidence tranche."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh086EvidenceTests(unittest.TestCase):
    def test_report_records_independent_gates(self):
        report = (ROOT / "results/tapenade_set01_lh086_validation.txt").read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "upstream_exact_source_compile_statuses:",
            "fortad_transform_compile_statuses:",
            "independent_oracle: hand Newton-map JVP/VJP",
        ):
            self.assertIn(marker, report)

    def test_ledger_row_closes_lh086(self):
        with (ROOT / "docs/corpora/tapenade-status.csv").open(
            encoding="utf-8", newline=""
        ) as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["nonRegressions/set01/lh086"]
        self.assertEqual(row["status"], "runnable-ported")
        self.assertEqual(row["fortad_result"], "pass-transform-compile-runtime")
        self.assertIn("pass-fresh-parser", row["tapenade_result"])

    def test_manifest_and_runner_are_pinned(self):
        manifest = (ROOT / "cases/tapenade-set01/tranche-o-lh086-manifest.toml").read_text()
        self.assertIn('upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"', manifest)
        self.assertIn('id = "lh086"', manifest)
        self.assertIn('independent = ["x", "alpha"]', manifest)


if __name__ == "__main__":
    unittest.main()
