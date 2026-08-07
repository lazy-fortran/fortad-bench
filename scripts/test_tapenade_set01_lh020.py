#!/usr/bin/env python3
"""Contract checks for the set01 lh020 evidence tranche."""

import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh020EvidenceTests(unittest.TestCase):
    def test_manifest_describes_the_bounded_contract(self):
        with (ROOT / "cases/tapenade-set01/lh020-manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        case = manifest["case"][0]
        self.assertEqual(manifest["runner"], "scripts/bench_tapenade_set01_lh020.sh")
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(case["stored_references"], ["program_d.f", "program_b.f"])
        self.assertEqual(case["ported_entry_point"], "set01_lh020(x,y,n,x1_out,branch)")
        self.assertEqual(case["classification"], "runnable-ported")
        self.assertIn("n >= 1", case["domain"])

    def test_report_records_all_gates_and_independent_oracle(self):
        report = (ROOT / "results/tapenade_set01_lh020_validation.txt").read_text()
        required = (
            "required_fortad_commit: db0050259520b618e2a0aeba203c85a7613943b5",
            "tapenade_commit: e59864cab441d4175df75383b3ff58c3dcd26df9",
            "upstream_exact_source_compile_statuses:",
            "tapenade_oracle: fresh parser, tangent, and reverse files generated",
            "tapenade_generated_compile_statuses:",
            "fortad_oracle: bounded standard-conforming x1_out port",
            "independent_oracle: hand JVP/VJP",
            "oracle_status: pass",
            "max_fd_error:",
            "max_adjoint_residual:",
        )
        for marker in required:
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
