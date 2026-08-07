"""Contract and independent-oracle checks for the set01 lh031 evidence."""

import math
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CASE = ROOT / "cases" / "tapenade-set01"
RESULT = ROOT / "results" / "tapenade_set01_lh031_validation.txt"


class Lh031EvidenceTests(unittest.TestCase):
    def test_manifest_pins_case_and_tools(self):
        with (CASE / "lh031-manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"],
                         "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["baseline_fortad_commit"],
                         "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(manifest["upstream_path"],
                         "nonRegressions/set01/lh031/program.f")
        self.assertEqual(manifest["classification"],
                         "runnable-ported-with-exact-source-fortad-refusal")

    def test_report_records_all_compiler_and_runtime_gates(self):
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
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
            "fortad_port_reverse_x_status: 0",
            "fortad_port_reverse_y_status: 0",
            "fortad_port_reverse_z_status: 0",
            "oracle_status: pass",
            "independent_oracle: closed-form JVP/VJP, central-difference sweep, and adjoint identity",
        ):
            self.assertIn(marker, report)
        self.assertIn("fortad_exact_diagnostic: fortad: unsupported statement at line 9",
                      report)

    def test_scalar_oracle_is_independent_of_generated_files(self):
        x, y, z = 0.7, -0.2, 1.1
        dx, dy, dz = -0.04, 0.01, 0.02
        bx, by, bz = 0.5, -0.3, 0.2

        a = x + math.sin(x) - y
        b = y * a
        da = (1.0 + math.cos(x)) * dx - dy
        db = dy * a + y * da
        dc = dz + da * b + a * db
        a_bar = bx + bz * b + bz * a * y + by * y
        expected_x = a_bar * (1.0 + math.cos(x))
        expected_y = bz * a * a + by * a - a_bar
        expected_z = bz
        lhs = bx * (da) + by * db + bz * dc
        rhs = dx * expected_x + dy * expected_y + dz * expected_z
        self.assertTrue(all(math.isfinite(value) for value in (a, b, da, db, dc)))
        self.assertAlmostEqual(lhs, rhs, places=13)
        self.assertAlmostEqual(expected_z, bz, places=15)


if __name__ == "__main__":
    unittest.main()
