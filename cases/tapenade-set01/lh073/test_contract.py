#!/usr/bin/env python3
"""Behavioral and evidence-contract checks for the lh073 case."""

from __future__ import annotations

import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
# CASE.parents[2] is the bench root: cases/tapenade-set01/lh073 -> bench.
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(CASE.parents[2] / "upstream" / "tapenade"))
)
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh073"


class Lh073ContractTests(unittest.TestCase):
    def test_manifest_pins_boundary_and_dependency(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-with-bounded-concrete-callback-port",
        )
        self.assertEqual(manifest["source_form"], "fixed")
        self.assertEqual(manifest["missing_dependencies"], ["DIFFSIZES.inc"])
        self.assertIn("nonRegressions/set01/lh073/program_dv.f", manifest["upstream_sources"])

    def test_independent_oracle_is_behavioral(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertIn("finite_difference_max_error:", completed.stdout)
        self.assertIn("adjoint_identity_residual:", completed.stdout)

    def test_sources_and_result_contract(self) -> None:
        for name in (
            "program.f",
            "program_p.f",
            "program_d.f",
            "program_b.f",
            "program_dv.f",
            "program_p.msg",
            "program_d.msg",
            "program_b.msg",
            "program_dv.msg",
        ):
            self.assertTrue((UPSTREAM / name).is_file(), name)
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-concrete-callback-port",
            "upstream_exact_strict_compile: program=0 parser=0 tangent=0 reverse=0 multidirectional=1",
            "upstream_multidirectional_diagnostic: missing-DIFFSIZES.inc",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward: transform=0 compile=0",
            "fortad_bounded_reverse_objective: transform=0 compile=0",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
