#!/usr/bin/env python3
"""Committed evidence checks for Tapenade set01 lh010."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh010EvidenceTests(unittest.TestCase):
    def test_report_records_numerical_and_engine_oracles(self):
        report = (
            ROOT / "results/tapenade_set01_lh010_validation.txt"
        ).read_text()
        self.assertIn("oracle_status: pass", report)
        self.assertIn("fd_errors:", report)
        self.assertIn("adjoint_residual:", report)
        self.assertIn("tapenade_oracle: fresh parser, tangent, and adjoint", report)
        self.assertIn("fortad_forward_source_bytes:", report)
        self.assertIn("fortad_reverse_source_bytes:", report)

    def test_ledger_row_is_runnable(self):
        ledger = ROOT / "docs/corpora/tapenade-status.csv"
        with ledger.open(encoding="utf-8", newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["nonRegressions/set01/lh010"]
        self.assertEqual(row["status"], "runnable-ported")
        self.assertEqual(row["fortad_result"], "pass-transform-compile-runtime")
        self.assertEqual(row["tapenade_result"], "pass-transform-compile")


if __name__ == "__main__":
    unittest.main()
