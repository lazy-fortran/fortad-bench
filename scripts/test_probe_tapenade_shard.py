import importlib.util
import re
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("probe_tapenade_shard.py")
SPEC = importlib.util.spec_from_file_location("probe_tapenade_shard", SCRIPT)
assert SPEC and SPEC.loader
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)


class ProbeReportTest(unittest.TestCase):
    def test_render_is_bounded_and_does_not_claim_derivatives(self):
        rows = [
            {
                "component": "fortran-known-failures",
                "path": "todoF90/REFERENCES/v01",
                "source": "todoF90/REFERENCES/v01/program.f90",
                "source_form": "free",
                "status": "runnable",
                "compiler_evidence": "gfortran strict syntax check passed",
                "tapenade_evidence": "program_p output generated (parser probe only)",
                "fortad": "not-run; no derivative oracle",
            },
            {
                "component": "large-examples",
                "path": "examples/big01/lh062",
                "source": "examples/big01/lh062/program.f",
                "source_form": "fixed",
                "status": "missing-dependency",
                "compiler_evidence": "gfortran reported a missing include or module",
                "tapenade_evidence": "program_p output generated (parser probe only)",
                "fortad": "not-run; no derivative oracle",
            },
        ]
        report = PROBE.render(rows)
        self.assertIn("| `runnable` | 1 |", report)
        self.assertIn("| `missing-dependency` | 1 |", report)
        self.assertIn("| **total** | **2** |", report)
        self.assertNotIn("/tmp/", report)
        self.assertNotIn("/var/", report)
        self.assertIn("not a FortAD support claim", report)
        self.assertEqual(report.count("not-run; no derivative oracle"), 2)

    def test_committed_report_has_all_shard_rows_and_expected_oracle_boundary(self):
        report = PROBE.REPORT.read_text(encoding="utf-8")
        self.assertIn(f"Pinned revision: `{PROBE.REVISION}`", report)
        expected = {
            "runnable": 35,
            "parser-failure": 1,
            "missing-dependency": 9,
            "invalid-source": 14,
        }
        for status, count in expected.items():
            self.assertIn(f"| `{status}` | {count} |", report)
        self.assertIn("| **total** | **59** |", report)
        evidence_rows = [
            line for line in report.splitlines()
            if line.startswith("| ") and "`examples/" in line or line.startswith("| ") and "`todoF90/" in line
        ]
        self.assertEqual(len(evidence_rows), 59)
        self.assertEqual(report.count("not-run; no derivative oracle"), 59)
        self.assertIsNone(re.search(r"/(?:tmp|var)/", report))


if __name__ == "__main__":
    unittest.main()
