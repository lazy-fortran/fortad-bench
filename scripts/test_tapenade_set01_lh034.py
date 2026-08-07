"""Contract checks for the isolated Tapenade set01/lh034 evidence."""

from pathlib import Path
import tomllib
import unittest


ROOT = Path(__file__).resolve().parent.parent
CASE = ROOT / "cases" / "tapenade-set01" / "lh034"
RESULT = ROOT / "results" / "tapenade_set01_lh034_validation.txt"


class Lh034ContractTests(unittest.TestCase):
    def test_manifest_records_exact_boundary_and_pins(self):
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)

        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "db0050259520b618e2a0aeba203c85a7613943b5",
        )
        case = manifest["case"][0]
        self.assertEqual(
            case["upstream_source"],
            "nonRegressions/set01/lh034/program.f",
        )
        self.assertEqual(
            case["classification"],
            "expected-refusal-with-bounded-forward-port",
        )
        self.assertIn("program_d.f", case["stored_references"])

    def test_report_records_all_engine_and_behavioral_gates(self):
        report = RESULT.read_text(encoding="utf-8")
        for expected in (
            "program.status 0",
            "program_d.status 0",
            "program_d.msg.present 1",
            "program_b.f.present 0",
            "program_dv.f.present 0",
            "parser.status 0",
            "forward.status 0",
            "reverse.status 1",
            "fortad_exact_forward_status: 1",
            "fortad_exact_reverse_status: 1",
            "fortad_port_forward_status: 0",
            "fortad_port_reverse_status: 1",
            "oracle_status: pass",
        ):
            self.assertIn(expected, report)
        self.assertIn(
            "fortad: unsupported statement at line 23",
            report,
        )
        self.assertIn(
            "fortad: reverse mode: a branch inside a loop needs control-flow reversal",
            report,
        )
        self.assertRegex(report, r"fd_errors:\s+[0-9.eE+-]+")
        self.assertRegex(report, r"adjoint_residual:\s+[0-9.eE+-]+")


if __name__ == "__main__":
    unittest.main()
