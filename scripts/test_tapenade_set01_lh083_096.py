#!/usr/bin/env python3
"""Contract checks for the set01 lh085/lh092 evidence tranche."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh083096EvidenceTests(unittest.TestCase):
    def test_report_records_independent_gates(self):
        report = (ROOT / "results/tapenade_set01_lh083_096_validation.txt").read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "upstream_exact_source_compile_statuses:",
            "fortad_transform_compile_statuses:",
            "independent_oracle: hand JVP/VJP",
        ):
            self.assertIn(marker, report)

    def test_ledger_rows_close_the_selected_set01_cases(self):
        with (ROOT / "docs/corpora/tapenade-status.csv").open(
            encoding="utf-8", newline=""
        ) as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        for path in ("nonRegressions/set01/lh085", "nonRegressions/set01/lh092"):
            self.assertEqual(rows[path]["status"], "runnable-ported")
            self.assertEqual(rows[path]["fortad_result"], "pass-transform-compile-runtime")
            self.assertIn("pass-fresh-parser", rows[path]["tapenade_result"])

    def test_manifest_and_runner_are_pinned(self):
        manifest = (ROOT / "cases/tapenade-set01/tranche-n-lh083-096-manifest.toml").read_text()
        self.assertIn('upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"', manifest)
        self.assertIn('id = "lh085"', manifest)
        self.assertIn('id = "lh092"', manifest)
        self.assertIn('independent = ["a", "b"]', manifest)


if __name__ == "__main__":
    unittest.main()
