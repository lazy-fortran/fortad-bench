import csv
import re
import stat
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPORT = ROOT / "results" / "tapenade_f03typf01_oo_validation.txt"
LEDGER = ROOT / "docs" / "corpora" / "tapenade-status.csv"
RUNNER = ROOT / "scripts" / "bench_tapenade_f03typf01_oo.sh"


class TapenadeF03Typf01EvidenceTests(unittest.TestCase):
    def test_report_records_independent_oracle_and_both_boundaries(self):
        report = REPORT.read_text(encoding="utf-8")
        self.assertIn("upstream_primal_compile: pass", report)
        self.assertIn("upstream_reference_compile: pass", report)
        self.assertIn("tapenade_generated_compile_status: 1 (expected rejection)", report)
        self.assertIn("ported_primal_oracle: pass", report)
        self.assertIn("fortad_status: expected-refusal", report)
        self.assertIn("unsupported type-bound call 'value'", report)
        self.assertIn("PASS: Tapenade f03typf01 primal and finite-difference oracle", report)
        self.assertNotRegex(report, r"/(?:tmp|var/tmp)/")

    def test_ledger_row_points_to_reported_refusal_contract(self):
        with LEDGER.open(encoding="utf-8", newline="") as stream:
            rows = list(csv.DictReader(stream))
        row = next(row for row in rows if row["path"] == "nonRegressions/set12/f03typf01")
        self.assertEqual(row["status"], "expected-refusal")
        self.assertEqual(row["tapenade_result"], "generated-source-compile-rejection")
        self.assertEqual(row["fortad_result"], "unsupported-type-bound-call")
        self.assertNotIn("untriaged", row.values())

    def test_runner_is_executable_and_uses_bounded_workspace(self):
        mode = RUNNER.stat().st_mode
        self.assertTrue(mode & stat.S_IXUSR)
        text = RUNNER.read_text(encoding="utf-8")
        self.assertIn("mktemp -d \"$root/build/", text)
        self.assertNotIn("/tmp/", text)


if __name__ == "__main__":
    unittest.main()
