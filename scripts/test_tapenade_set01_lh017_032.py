"""Contract checks for the set01 lh017/lh022/lh028 evidence tranche."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class TrancheLEvidenceTests(unittest.TestCase):
    def test_report_contains_fresh_generation_and_independent_oracle(self):
        report = (ROOT / "results/tapenade_set01_lh017_032_validation.txt").read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse files generated",
            "lh022_diagnostic: fortad: reverse mode: 'y' is both read and written",
            "lh028_diagnostic: fortad: reverse mode: a branch inside a loop",
            "lh017_reverse_refusal_status: not-applicable (supported)",
        ):
            self.assertIn(marker, report)

    def test_ledger_records_one_support_and_two_boundaries(self):
        with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        self.assertEqual(rows["nonRegressions/set01/lh017"]["status"], "runnable-ported")
        self.assertEqual(rows["nonRegressions/set01/lh022"]["status"], "expected-refusal")
        self.assertEqual(rows["nonRegressions/set01/lh028"]["status"], "expected-refusal")

    def test_harness_has_fd_and_adjoint_checks(self):
        source = (ROOT / "harness/bench_tapenade_set01_lh017_032.f90").read_text()
        hand = (ROOT / "cases/tapenade-set01/hand_derivatives_lh017_032.f90").read_text()
        self.assertGreaterEqual(source.count("finite difference"), 2)
        self.assertGreaterEqual(source.count("adjoint identity"), 3)
        self.assertIn("subroutine lh022_vjp", hand)
        self.assertIn("subroutine lh028_vjp", hand)


if __name__ == "__main__":
    unittest.main()
