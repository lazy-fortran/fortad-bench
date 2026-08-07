#!/usr/bin/env python3
"""Behavioral and evidence-contract checks for the lh070 case."""

from __future__ import annotations

import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(CASE.parents[2] / "upstream" / "tapenade"))
)
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh070"


class Lh070ContractTests(unittest.TestCase):
    def test_manifest_pins_entry_and_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "0e156041c1f92736c1e35f8164b37992c4c8d780",
        )
        self.assertEqual(
            manifest["classification"], "expected-refusal-with-bounded-forward-port"
        )
        self.assertEqual(manifest["upstream_entry_point"], "top(A,B); F()")
        self.assertIn("nonRegressions/set01/lh070/program_dv.f", manifest["upstream_sources"])

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
        ):
            self.assertTrue((UPSTREAM / name).is_file(), name)
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "upstream_exact_strict_compile: primal=0 parser=0 tangent=0 reverse=0 multidirectional=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward: transform=pass status=0 compile=0",
            "fortad_bounded_reverse_y: transform=pass status=0 compile=0",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
