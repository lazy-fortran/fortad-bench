"""Contract checks for the Tapenade set01 lh026 evidence tranche."""

import stat
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "cases/tapenade-set01/tranche-lh026-manifest.toml"
REPORT = ROOT / "results/tapenade_set01_lh026_validation.txt"
RUNNER = ROOT / "scripts/bench_tapenade_set01_lh026.sh"


class Lh026EvidenceTests(unittest.TestCase):
    def test_report_records_all_independent_gates(self):
        report = REPORT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal",
            "tapenade_oracle: fresh parser, tangent, and reverse files generated",
            "fortad_forward_status: 0",
            "fortad_reverse_diagnostic: fortad: reverse mode: a branch inside a loop",
            "independent_oracle: structured reference primal, hand JVP/VJP",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)

    def test_manifest_pins_both_engines_and_records_bound(self):
        manifest = MANIFEST.read_text(encoding="utf-8")
        for marker in (
            'upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"',
            'fortad_revision = "db0050259520b618e2a0aeba203c85a7613943b5"',
            'stored_references = ["program_d.f", "program_b.f", "program_dv.f"]',
            'classification = "expected-refusal"',
            "at most 100 restart sweeps",
        ):
            self.assertIn(marker, manifest)

    def test_runner_is_executable_and_case_local(self):
        self.assertTrue(RUNNER.stat().st_mode & stat.S_IXUSR)
        text = RUNNER.read_text(encoding="utf-8")
        self.assertIn("-std=f2018 -pedantic-errors -ffixed-line-length-none", text)
        self.assertIn("fo exec --no-build fortad", text)
        self.assertIn("DIFFSIZES.f", text)
        self.assertNotIn("docs/corpora", text)
        self.assertNotIn("ROADMAP.md", text)
        self.assertNotIn("README.md", text)


if __name__ == "__main__":
    unittest.main()
