#!/usr/bin/env python3
"""Behavioral and evidence-contract checks for the case-local lh041 probe."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = CASE.parents[2] / "upstream" / "tapenade" / "nonRegressions" / "set01" / "lh041"


class Lh041ContractTests(unittest.TestCase):
    def test_manifest_pins_exact_case_and_boundaries(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(manifest["upstream_entry_point"], "adj10(tab,q)")
        self.assertEqual(manifest["classification"], "runnable-ported-with-exact-source-fortad-refusal")
        self.assertEqual(manifest["source_form"], "fixed")
        self.assertIn("nonRegressions/set01/lh041/program_dv.f", manifest["upstream_sources"])

    def test_independent_oracle_has_behavioral_pass(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertIn("fd_error:", completed.stdout)
        self.assertIn("adjoint_identity_residual:", completed.stdout)

    def test_exact_sources_are_present_and_result_records_all_gates(self) -> None:
        for name in ("program.f", "program_d.f", "program_b.f", "program_dv.f", "program_p.f"):
            self.assertTrue((UPSTREAM / name).is_file(), name)
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: runnable-ported-with-exact-source-fortad-refusal",
            "upstream_program.f_strict_compile: pass",
            "upstream_program_d.f_strict_compile: pass",
            "upstream_program_b.f_strict_compile: pass",
            "upstream_program_dv.f_strict_compile: expected-refusal",
            "upstream_program_p.f_strict_compile: pass",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_parser_strict_compile: pass",
            "tapenade_forward_strict_compile: pass",
            "tapenade_reverse_strict_compile: pass",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_port_forward: pass-transform-compile-runtime",
            "fortad_port_reverse: expected-refusal",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
