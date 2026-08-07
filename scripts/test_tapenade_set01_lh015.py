"""Contract checks for the isolated set01 lh015 refusal record."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent
RESULT = ROOT / "results" / "tapenade_set01_lh015_refusal_validation.txt"
MANIFEST = ROOT / "cases" / "tapenade-set01" / "tranche-lh015-manifest.toml"
HARNESS = ROOT / "harness" / "bench_tapenade_set01_lh015.f90"


class Lh015EvidenceTests(unittest.TestCase):
    def test_report_records_all_independent_gates(self):
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "tapenade_commit: e59864cab441d4175df75383b3ff58c3dcd26df9",
            "required_fortad_commit: db0050259520b618e2a0aeba203c85a7613943b5",
            "upstream-program 1",
            "upstream-program_d 1",
            "upstream-program_b 0",
            "parser 0",
            "forward 0",
            "reverse 0",
            "tapenade-parser 1",
            "tapenade-forward 1",
            "tapenade-reverse 0",
            "forward 1",
            "reverse 1",
            "fortad: unsupported statement at line 8",
            "oracle_status: pass",
            "status: expected-refusal",
        ):
            self.assertIn(marker, report)

    def test_manifest_forbids_a_repaired_port_claim(self):
        manifest = MANIFEST.read_text(encoding="utf-8")
        self.assertIn('id = "lh015"', manifest)
        self.assertIn(
            'upstream_source = "nonRegressions/set01/lh015/program.f"',
            manifest,
        )
        self.assertIn(
            'classification = "unsupported-invalid-upstream-fortran"',
            manifest,
        )
        self.assertIn('ported_entry_point = "none"', manifest)

    def test_harness_contains_independent_derivative_oracles(self):
        source = HARNESS.read_text(encoding="utf-8")
        self.assertIn("central-difference", source)
        self.assertIn("adjoint identity", source)
        self.assertIn("set01_lh015_safe_primal", source)
        self.assertIn("set01_lh015_hand", source)


if __name__ == "__main__":
    unittest.main()
