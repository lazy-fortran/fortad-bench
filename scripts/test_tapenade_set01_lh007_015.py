"""Contract checks for exact-source Tapenade set01 lh012-014 evidence."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESULT = ROOT / "results" / "tapenade_set01_lh007_015_refusal_validation.txt"
LEDGER = ROOT / "docs" / "corpora" / "tapenade-status.csv"
MANIFEST = ROOT / "cases" / "tapenade-set01" / \
    "tranche-l-lh007-015-manifest.toml"
HARNESS = ROOT / "harness" / "bench_tapenade_set01_lh007_015.f90"


class Lh007015EvidenceTests(unittest.TestCase):
    def test_report_records_fresh_generation_and_refusal_diagnostics(self):
        report = RESULT.read_text(encoding="utf-8")
        self.assertIn("oracle_status: pass", report)
        self.assertIn("tapenade_result: fresh parser, tangent, and reverse", report)
        self.assertIn("lh012_fortad_generated_compile_statuses:\nforward 0\nreverse 1", report)
        self.assertIn("lh013_fortad_generated_compile_statuses:\nforward 0\nreverse 1", report)
        self.assertIn("lh014_fortad_generated_compile_statuses:\nforward 1\nreverse 1", report)
        self.assertIn("Function ‘indx’", report)
        self.assertIn("Duplicate symbol ‘x_b’", report)
        self.assertIn("Symbol ‘i’", report)

    def test_manifest_keeps_three_exact_source_rows(self):
        manifest = MANIFEST.read_text(encoding="utf-8")
        for case_id in ("lh012", "lh013", "lh014"):
            self.assertIn(f'id = "{case_id}"', manifest)
            self.assertIn(
                f'upstream_source = "nonRegressions/set01/{case_id}/program.f"',
                manifest,
            )
        self.assertEqual(manifest.count("classification = \"unsupported-exact-source"), 3)

    def test_ledger_rows_are_expected_refusals(self):
        with LEDGER.open(encoding="utf-8", newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        for case_id in ("lh012", "lh013", "lh014"):
            row = rows[f"nonRegressions/set01/{case_id}"]
            self.assertEqual(row["status"], "expected-refusal")
            self.assertIn("pass-", row["fortad_result"])
            self.assertIn("pass-fresh-parser", row["tapenade_result"])

    def test_harness_contains_independent_fd_and_adjoint_oracles(self):
        source = HARNESS.read_text(encoding="utf-8")
        self.assertIn("central difference", source)
        self.assertIn("adjoint identity", source)
        self.assertIn("subroutine check_lh012", source)
        self.assertIn("subroutine check_lh013", source)
        self.assertIn("subroutine check_lh014", source)


if __name__ == "__main__":
    unittest.main()
