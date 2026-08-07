#!/usr/bin/env python3
"""Contract and independent-oracle checks for case-local lh065 evidence."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
import os
from pathlib import Path


CASE = Path(__file__).resolve().parent
# CASE.parents[2] is the bench root: cases/tapenade-set01/lh065 -> bench.
UPSTREAM = Path(
    os.environ.get("TAPENADE_REPO", str(CASE.parents[2] / "upstream" / "tapenade"))
) / "nonRegressions" / "set01" / "lh065"


class Lh065ContractTests(unittest.TestCase):
    def test_manifest_preserves_pins_and_invalid_closure(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "0e156041c1f92736c1e35f8164b37992c4c8d780")
        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["source_form"], "fixed")
        self.assertEqual(manifest["upstream_entry_point"], "top(in,out,N)")
        self.assertEqual(
            manifest["upstream_sources"],
            [
                "nonRegressions/set01/lh065/program.f",
                "nonRegressions/set01/lh065/program_p.f",
                "nonRegressions/set01/lh065/program_d.f",
            ],
        )
        self.assertEqual(manifest["missing_stored_references"], ["program_b.f", "program_b.msg", "program_dv.f"])

    def test_independent_compiler_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_program.f: expected-refusal", completed.stdout)
        self.assertIn("oracle_program_d.f: expected-refusal", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_all_generation_and_refusal_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "entry_point: top(in,out,N)",
            "upstream_program.f_strict_compile: expected-refusal",
            "upstream_program_p.f_strict_compile: expected-refusal",
            "upstream_program_d.f_strict_compile: expected-refusal",
            "missing_stored_references: program_b.f/.msg program_dv.f",
            "tapenade_generation: parser=pass forward=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=expected-refusal forward=expected-refusal reverse=expected-refusal",
            "fortad_forward: expected-refusal COMMON line 9",
            "fortad_reverse: expected-refusal COMMON line 9",
            "oracle_status: pass",
            "closure: no standard-conforming port or support claim",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
