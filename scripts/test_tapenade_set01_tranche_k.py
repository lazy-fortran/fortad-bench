#!/usr/bin/env python3
"""Contract checks for the exact-source tranche K refusal record."""

import csv
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent
RESULT = ROOT / "results" / "tapenade_set01_tranche_k_refusal_validation.txt"
LEDGER = ROOT / "docs" / "corpora" / "tapenade-status.csv"
MANIFEST = ROOT / "cases" / "tapenade-set01" / "tranche-k-manifest.toml"
HARNESS = ROOT / "harness" / "bench_tapenade_set01_tranche_k.f90"


class TrancheKEvidenceTests(unittest.TestCase):
    def test_report_records_all_refusals_and_oracle(self):
        report = RESULT.read_text()
        for marker in (
            "oracle_status: pass",
            "lh003_fortad_diagnostic:\nfortad: unsupported statement at line 11",
            "lh005_fortad_diagnostic:\nfortad: parse failed: ERROR at line 37",
            "lh006_fortad_diagnostic:\nfortad: parse failed: Unterminated character constant at line 49",
            "tapenade_result: fresh parser, tangent, and reverse outputs generated",
        ):
            self.assertIn(marker, report)

    def test_manifest_keeps_exact_source_boundary(self):
        manifest = MANIFEST.read_text()
        self.assertIn('name = "tapenade-set01-tranche-k"', manifest)
        self.assertEqual(manifest.count('classification = "unsupported-exact-source"'), 3)
        self.assertIn('upstream_source = "nonRegressions/set01/lh003/program.f"', manifest)
        self.assertIn('upstream_source = "nonRegressions/set01/lh005/program.f"', manifest)
        self.assertIn('upstream_source = "nonRegressions/set01/lh006/program.f"', manifest)

    def test_ledger_rows_are_expected_refusals(self):
        with LEDGER.open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        expected = {
            "nonRegressions/set01/lh003": "pass-exact-source-refusal-unsupported-statement-line-11",
            "nonRegressions/set01/lh005": "pass-exact-source-refusal-unmatched-do-line-37",
            "nonRegressions/set01/lh006": "pass-exact-source-refusal-unterminated-character-line-49",
        }
        for path, result in expected.items():
            self.assertEqual(rows[path]["status"], "expected-refusal")
            self.assertEqual(rows[path]["fortad_result"], result)

    def test_independent_oracle_has_hand_tangent_and_fd(self):
        source = HARNESS.read_text()
        self.assertIn("subroutine lh003_tangent", source)
        self.assertIn("(ap - am) / (2.0_dp * eps)", source)
        self.assertIn("subroutine lh005_x1", source)
        self.assertIn("subroutine lh006_x1", source)


if __name__ == "__main__":
    unittest.main()
