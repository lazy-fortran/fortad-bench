#!/usr/bin/env python3
"""Behavioral and evidence-contract tests for bounded lh060."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


class Lh060ContractTests(unittest.TestCase):
    def test_manifest_pins_boundary_and_port_contract(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "0e156041c1f92736c1e35f8164b37992c4c8d780")
        self.assertEqual(manifest["classification"], "expected-refusal-with-bounded-forward-port")
        self.assertEqual(manifest["upstream_entry_point"], "invert(neq,y,savf,FX3,FX4)")
        self.assertEqual(
            manifest["ported_entry_point"],
            "set01_lh060(neq,y,savf,tn,c3,c4,y_out,savf_out,tn_out)",
        )

    def test_independent_python_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_all_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "upstream_exact_strict_compile: program=0 parser=0 tangent=0 reverse=1 multidirectional=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=1",
            "fortad_exact_forward: expected-refusal status=1",
            "fortad_exact_reverse: expected-refusal status=1",
            "fortad_bounded_forward_generation: pass",
            "fortad_bounded_reverse_generation: y_out=pass savf_out=pass tn_out=pass",
            "fortad_bounded_forward_strict_compile: 0",
            "fortad_bounded_reverse_strict_compile: y_out=0 savf_out=0 tn_out=0",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
