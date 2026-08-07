#!/usr/bin/env python3
"""Behavioral and evidence-contract tests for bounded lh051."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


class Lh051ContractTests(unittest.TestCase):
    def test_manifest_pins_boundary_and_port_contract(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(manifest["classification"], "expected-refusal-with-bounded-forward-port")
        self.assertEqual(manifest["upstream_entry_point"], "adj1(x,y,z,n,o)")
        self.assertEqual(manifest["ported_entry_point"], "set01_lh051(x,y,z,n,o)")

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
            "upstream_exact_strict_compile: program=0 tangent=0 reverse=0",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward_strict_compile: 0",
            "fortad_bounded_reverse_generation: x=refusal y=refusal z=refusal",
            "per-iteration storage",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
