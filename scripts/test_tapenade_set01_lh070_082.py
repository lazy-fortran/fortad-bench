#!/usr/bin/env python3
"""Contract checks for the set01 lh074/lh080/lh082 evidence tranche."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh070082EvidenceTests(unittest.TestCase):
    def test_report_records_independent_gates(self):
        report = (ROOT / "results/tapenade_set01_lh070_082_validation.txt").read_text()
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
        self.assertEqual(rows["nonRegressions/set01/lh074"]["status"], "expected-refusal")
        self.assertEqual(rows["nonRegressions/set01/lh080"]["status"], "runnable-ported")
        self.assertEqual(rows["nonRegressions/set01/lh082"]["status"], "expected-refusal")
        self.assertIn("pass-transform-compile-runtime", rows["nonRegressions/set01/lh080"]["fortad_result"])

    def test_manifest_and_runner_are_pinned(self):
        manifest = (ROOT / "cases/tapenade-set01/tranche-m-lh070-082-manifest.toml").read_text()
        self.assertIn('upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"', manifest)
        self.assertIn('id = "lh074"', manifest)
        self.assertIn('id = "lh080"', manifest)
        self.assertIn('id = "lh082"', manifest)


if __name__ == "__main__":
    unittest.main()
