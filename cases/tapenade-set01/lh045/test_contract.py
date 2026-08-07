#!/usr/bin/env python3
"""Behavioral and evidence-contract tests for the bounded lh045 case."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


class Lh045ContractTests(unittest.TestCase):
    def test_manifest_pins_boundary_and_port_contract(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(manifest["classification"], "expected-refusal-with-bounded-forward-port")
        self.assertEqual(manifest["upstream_entry_point"], "S1(x,i1,y,i2,z)")
        self.assertEqual(manifest["ported_entry_point"], "set01_lh045(x,y,w4,v2,x_out,z,w4_out)")

    def test_independent_python_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_exact_fresh_and_fortad_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "upstream_exact_strict_compile: program=0 tangent=0 reverse=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=1",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward_strict_compile: 0",
            "fortad_bounded_reverse_strict_compile: x_out=refusal z=refusal w4_out=refusal",
            "0.0_kind=8",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
