"""Contract checks for the set01 lh033/lh039/lh040 evidence tranche."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh033047EvidenceTests(unittest.TestCase):
    def test_report_records_all_engine_and_numerical_gates(self):
        report = (ROOT / "results/tapenade_set01_lh033_047_validation.txt").read_text()
        for marker in (
            "tapenade_generated_compile: pass-strict",
            "fortad_oracle: lh039 forward and reverse transform compile and run",
            "oracle: independent hand JVP, central-difference sweeps, and VJP adjoint identity",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)

    def test_ledger_closes_one_support_and_two_source_boundaries(self):
        with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        self.assertEqual(rows["nonRegressions/set01/lh033"]["status"], "expected-refusal")
        self.assertEqual(rows["nonRegressions/set01/lh033"]["tapenade_result"],
                         "pass-fresh-parser-tangent-reverse-generation-generated-compile")
        self.assertEqual(rows["nonRegressions/set01/lh039"]["status"], "runnable-ported")
        self.assertEqual(rows["nonRegressions/set01/lh039"]["fortad_result"],
                         "pass-transform-compile-runtime")
        self.assertEqual(rows["nonRegressions/set01/lh040"]["status"], "expected-refusal")

    def test_case_and_runner_keep_exact_source_contract(self):
        manifest = (ROOT / "cases/tapenade-set01/tranche-m-lh033-047-manifest.toml").read_text()
        runner = (ROOT / "scripts/bench_tapenade_set01_lh033_047.sh").read_text()
        harness = (ROOT / "harness/bench_tapenade_set01_lh033_047.f90").read_text()
        self.assertIn('upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"', manifest)
        self.assertIn("unsupported statement at line $line", runner)
        self.assertIn("adjoint_residual", harness)


if __name__ == "__main__":
    unittest.main()
