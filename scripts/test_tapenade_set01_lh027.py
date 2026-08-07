"""Contract checks for the set01 lh027 evidence tranche."""

import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CASE = ROOT / "cases" / "tapenade-set01"
RESULT = ROOT / "results" / "tapenade_set01_lh027_validation.txt"


class Lh027EvidenceTests(unittest.TestCase):
    def test_manifest_pins_exact_case_and_tools(self):
        with (CASE / "lh027-manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"],
                         "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["baseline_fortad_commit"],
                         "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(manifest["upstream_path"],
                         "nonRegressions/set01/lh027/program.f")
        self.assertEqual(manifest["classification"], "runnable-ported")

    def test_result_records_strict_gates_and_independent_runtime_oracle(self):
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "upstream_program_strict_compile_status: 0",
            "upstream_program_d_strict_compile_status: 0",
            "upstream_program_b_strict_compile_status: 1",
            "upstream_program_dv_strict_compile_status: 1",
            "tapenade_parser_strict_compile_status: 0",
            "tapenade_forward_strict_compile_status: 0",
            "tapenade_reverse_strict_compile_status: 1",
            "fortad_exact_forward_compile_status: 0",
            "fortad_port_forward_status: 0",
            "fortad_port_reverse_status: 0",
            "oracle_status: pass",
            "independent_oracle: closed-form array/scalar JVP/VJP, central-difference sweep, and adjoint identity",
        ):
            self.assertIn(marker, report)
        self.assertIn("fortad_exact_reverse_diagnostic: fortad: assignment to undeclared ')'", report)

    def test_case_artifacts_are_present(self):
        for relative in (
            "lh027.f90",
            "hand_derivative_lh027.f90",
            "lh027-manifest.toml",
            "lh027.md",
        ):
            self.assertTrue((CASE / relative).is_file(), relative)
        for relative in (
            "harness/bench_tapenade_set01_lh027.f90",
            "scripts/bench_tapenade_set01_lh027.sh",
        ):
            self.assertTrue((ROOT / relative).is_file(), relative)


if __name__ == "__main__":
    unittest.main()
