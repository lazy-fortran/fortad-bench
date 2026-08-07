"""Contract checks for the isolated Tapenade set01 lh029 evidence package."""

import stat
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CASE = ROOT / "cases" / "tapenade-set01"
MANIFEST = CASE / "lh029-manifest.toml"
REPORT = ROOT / "results" / "tapenade_set01_lh029_validation.txt"
RUNNER = ROOT / "scripts" / "bench_tapenade_set01_lh029.sh"


class Lh029EvidenceTests(unittest.TestCase):
    def test_manifest_pins_case_and_engines(self):
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["baseline_fortad_commit"],
            "db0050259520b618e2a0aeba203c85a7613943b5",
        )
        self.assertEqual(
            manifest["upstream_source"],
            "nonRegressions/set01/lh029/program.f",
        )
        self.assertEqual(
            manifest["classification"],
            "runnable-ported-with-exact-source-fortad-refusal",
        )
        self.assertEqual(
            manifest["stored_references"],
            [
                "program_d.f",
                "program_b.f",
                "program_dv.f",
                "program_b.msg",
                "program_d.msg",
                "program_dv.msg",
            ],
        )

    def test_report_records_strict_fresh_and_independent_gates(self):
        report = REPORT.read_text(encoding="utf-8")
        for marker in (
            "classification: runnable-ported-with-exact-source-fortad-refusal",
            "upstream_program_strict_compile_status: 0",
            "upstream_program_d_strict_compile_status: 0",
            "upstream_program_b_strict_compile_status: 0",
            "upstream_program_dv_strict_compile_status: 0",
            "tapenade_parser_strict_compile_status: 0",
            "tapenade_forward_strict_compile_status: 0",
            "tapenade_reverse_strict_compile_status: 0",
            "fortad_exact_forward_status: 1",
            "fortad_exact_reverse_status: 1",
            "fortad_port_forward_status: 0",
            "fortad_port_reverse_xx_status: 0",
            "fortad_port_reverse_z_out_status: 0",
            "independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        self.assertIn(
            "fortad_exact_diagnostic: inlining s2 needs plain variables as arguments",
            report,
        )

    def test_case_paths_and_runner_are_namespaced(self):
        for relative in (
            "lh029.f90",
            "hand_derivatives_lh029.f90",
            "lh029-manifest.toml",
            "lh029.md",
        ):
            self.assertTrue((CASE / relative).is_file(), relative)
        self.assertTrue((ROOT / "harness/bench_tapenade_set01_lh029.f90").is_file())
        self.assertTrue(RUNNER.is_file())
        self.assertTrue(RUNNER.stat().st_mode & stat.S_IXUSR)
        text = RUNNER.read_text(encoding="utf-8")
        self.assertIn("DIFFSIZES.f", text)
        self.assertIn("fo exec --no-build fortad", text)
        self.assertNotIn("docs/corpora", text)
        self.assertNotIn("ROADMAP.md", text)
        self.assertNotIn("README.md", text)


if __name__ == "__main__":
    unittest.main()
