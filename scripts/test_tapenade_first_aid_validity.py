#!/usr/bin/env python3
"""Committed evidence checks for the first-aid validity refusal."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class FirstAidValidityEvidenceTests(unittest.TestCase):
    def test_report_records_independent_oracle_and_exact_refusal(self):
        report = (
            ROOT / "results/tapenade_first_aid_validity_refusal_validation.txt"
        ).read_text()
        self.assertIn("oracle_status: pass", report)
        self.assertIn("state_transitions_checked: 8", report)
        self.assertIn("fortad_forward_status: 1", report)
        self.assertIn(
            "fortad_diagnostic: fortad: unsupported statement at line 21",
            report,
        )
        self.assertIn("tapenade_oracle: fresh parser, forward, and reverse", report)

    def test_ledger_row_is_an_expected_refusal(self):
        ledger = ROOT / "docs/corpora/tapenade-status.csv"
        with ledger.open(encoding="utf-8", newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["ADFirstAidKit/validityTest.f"]
        self.assertEqual(row["status"], "expected-refusal")
        self.assertEqual(row["fortad_result"], "unsupported-common-block")
        self.assertEqual(row["tapenade_result"], "pass-transform-compile")


if __name__ == "__main__":
    unittest.main()
