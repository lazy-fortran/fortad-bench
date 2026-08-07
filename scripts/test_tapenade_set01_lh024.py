"""Contract checks for the isolated set01/lh024 refusal record."""

from pathlib import Path
import tomllib
import unittest


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "cases" / "tapenade-set01" / "lh024-manifest.toml"
RESULT = ROOT / "results" / "tapenade_set01_lh024_validation.txt"


class Lh024ContractTests(unittest.TestCase):
    def test_manifest_keeps_exact_source_boundary(self):
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
            manifest["upstream_source"], "nonRegressions/set01/lh024/program.f"
        )
        self.assertEqual(
            manifest["classification"], "expected-refusal-exact-source-call-boundary"
        )
        self.assertIn("DIFFSIZES.f", manifest["dependencies"])

    def test_report_records_independent_behavior_and_refusal_gates(self):
        report = RESULT.read_text(encoding="utf-8")

        for expected in (
            "upstream-program.status 0",
            "upstream-program_d.status 0",
            "upstream-program_dv.status 0",
            "upstream-program_b.status 0",
            "tapenade-parser.status 0",
            "tapenade-forward.status 0",
            "tapenade-reverse.status 0",
            "fortad_exact_forward_status: 1",
            "fortad_exact_reverse_status: 1",
            "fortad_port_forward_status: 0",
            "fortad_port_reverse_status: 1",
            "oracle_status: pass",
        ):
            self.assertIn(expected, report)
        self.assertIn(
            "fortad: inlining sub1 needs plain variables as arguments",
            report,
        )
        self.assertIn(
            "fortad: reverse mode: 'x' is both read and written in the same loop",
            report,
        )
        self.assertRegex(report, r"fd_errors: +[0-9.eE+-]+")
        self.assertRegex(report, r"adjoint_residual: +[0-9.eE+-]+")
        self.assertIn("status: expected-refusal", report)


if __name__ == "__main__":
    unittest.main()
