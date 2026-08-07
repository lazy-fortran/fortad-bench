#!/usr/bin/env python3
"""Contract checks for the lh008 numerical evidence record."""

import csv
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent
CASE = ROOT / "cases" / "tapenade-set01"
RESULT = ROOT / "results" / "tapenade_set01_lh008_validation.txt"
LEDGER = ROOT / "docs" / "corpora" / "tapenade-status.csv"


class Lh008EvidenceTests(unittest.TestCase):
    def test_report_records_independent_gates(self):
        report = RESULT.read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_generated_compile: pass-strict",
            "oracle: independent hand JVP/VJP",
            "tapenade_result: parser and generated forward/reverse",
        ):
            self.assertIn(marker, report)

    def test_case_retains_state_write_and_hand_oracle(self):
        source = (CASE / "lh008.f90").read_text()
        hand = (CASE / "hand_derivatives_lh008.f90").read_text()
        self.assertIn("y = 0.0_dp", source)
        self.assertIn("subroutine lh008_hand_vjp", hand)

    def test_ledger_row_is_promoted(self):
        with LEDGER.open(newline="") as stream:
            rows = list(csv.DictReader(stream))
        row = next(item for item in rows if item["path"] ==
                   "nonRegressions/set01/lh008")
        self.assertEqual(row["status"], "runnable-ported")
        self.assertEqual(row["fortad_result"], "pass-transform-compile-runtime")


if __name__ == "__main__":
    unittest.main()
