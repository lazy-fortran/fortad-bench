"""Committed-evidence checks for the Tapenade set01 bd05 tranche."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class Bd05EvidenceTests(unittest.TestCase):
    def test_artifacts_and_result_are_present(self):
        paths = [
            ROOT / "cases/tapenade-set01/bd05.f90",
            ROOT / "cases/tapenade-set01/hand_derivative_bd05.f90",
            ROOT / "cases/tapenade-set01/tranche-p-bd05-manifest.toml",
            ROOT / "harness/bench_tapenade_set01_bd05.f90",
            ROOT / "scripts/bench_tapenade_set01_bd05.sh",
            ROOT / "results/tapenade_set01_bd05_validation.txt",
        ]
        for path in paths:
            self.assertTrue(path.is_file(), path)

    def test_result_records_independent_gates(self):
        result = (ROOT / "results/tapenade_set01_bd05_validation.txt").read_text()
        for marker in (
            "upstream_exact_source_compile_statuses:",
            "tapenade_oracle: fresh parser, tangent, and reverse files generated",
            "independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity with preserved reverse seed",
            "oracle_status: pass",
        ):
            self.assertIn(marker, result)
        self.assertNotIn("FAIL", result)

    def test_manifest_pins_source_and_interface(self):
        manifest = (ROOT / "cases/tapenade-set01/tranche-p-bd05-manifest.toml").read_text()
        for marker in (
            'upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"',
            'upstream_source = "nonRegressions/set01/bd05/program.f"',
            'independent = ["a_in", "b_in", "c_in"]',
            'dependent = "c_out"',
            "bounded scalar projection",
        ):
            self.assertIn(marker, manifest)


if __name__ == "__main__":
    unittest.main()
