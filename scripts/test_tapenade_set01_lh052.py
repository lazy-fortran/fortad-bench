#!/usr/bin/env python3
"""Contract checks for the lh052 strict-source refusal evidence."""

import csv
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class Lh052RefusalTests(unittest.TestCase):
    def test_manifest_and_report_describe_the_same_refusal(self):
        with (ROOT / "cases/tapenade-set01/tranche-m-lh052-manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        report = (ROOT / "results/tapenade_set01_lh052_refusal_validation.txt").read_text()
        self.assertEqual(manifest["runner"], "scripts/bench_tapenade_set01_lh052.sh")
        self.assertIn("tapenade_forward_generation: pass", report)
        self.assertIn("tapenade_forward_strict_compile: expected-refusal", report)
        self.assertIn("fortad_result: not-run-invalid-upstream-source", report)
        self.assertIn("refusal_oracle_status: pass", report)

    def test_ledger_marks_only_lh052_as_refused(self):
        with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = list(csv.DictReader(stream))
        row = next(item for item in rows if item["path"] == "nonRegressions/set01/lh052")
        nearby = next(item for item in rows if item["path"] == "nonRegressions/set01/lh057")
        self.assertEqual(row["status"], "unsupported-invalid-upstream-fortran")
        self.assertEqual(row["fortad_result"], "not-run-invalid-upstream-source")
        self.assertEqual(nearby["status"], "runnable-ported")


if __name__ == "__main__":
    unittest.main()
