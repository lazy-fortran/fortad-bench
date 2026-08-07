#!/usr/bin/env python3
"""Contract and independent behavioral checks for the lh037 evidence."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM = ROOT / "upstream" / "tapenade" / "nonRegressions" / "set01" / "lh037"


class Lh037ContractTests(unittest.TestCase):
    def test_manifest_records_pins_and_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        case = manifest["case"][0]
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(case["classification"], "unsupported-invalid-upstream-fortran")
        self.assertEqual(case["upstream_entry_point"], "assgoto1(a,b,c)")
        self.assertIn("program_dv.f", case["stored_references"])

    def test_independent_compiler_and_numerical_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertIn("finite_difference: pass", completed.stdout)
        self.assertIn("adjoint_identity: pass", completed.stdout)

    def test_result_records_all_required_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: unsupported-invalid-upstream-fortran",
            "upstream_exact_strict_compile: expected-refusal",
            "upstream_stored_reference_strict_compile: program_p=1 program_d=1 program_b=1 program_dv=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_generated_strict_compile: parser=expected-refusal tangent=expected-refusal reverse=expected-refusal",
            "fortad_exact_result: expected-refusal",
            "fortad_port_result: pass-transform-compile-runtime",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
