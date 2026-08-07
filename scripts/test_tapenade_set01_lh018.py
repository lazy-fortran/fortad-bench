#!/usr/bin/env python3
"""Committed evidence checks for Tapenade set01 lh018."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh018EvidenceTests(unittest.TestCase):
    def test_report_records_numerical_and_engine_oracles(self):
        report = (ROOT / "results/tapenade_set01_lh018_validation.txt").read_text()
        self.assertIn("oracle_status: pass", report)
        self.assertIn("fd_errors:", report)
        self.assertIn("adjoint_residual:", report)
        self.assertIn("tapenade_oracle: fresh parser, tangent, and reverse", report)

    def test_ledger_row_is_runnable_after_promotion(self):
        with (ROOT / "docs/corpora/tapenade-status.csv").open(
            encoding="utf-8", newline=""
        ) as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["nonRegressions/set01/lh018"]
        self.assertEqual(row["status"], "runnable-ported")
        self.assertEqual(row["fortad_result"], "pass-transform-compile-runtime")


if __name__ == "__main__":
    unittest.main()
