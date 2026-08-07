#!/usr/bin/env python3
"""Behavioral and evidence-contract checks for lh050."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = CASE.parents[2] / "upstream" / "tapenade" / "nonRegressions" / "set01" / "lh050"


class Lh050ContractTests(unittest.TestCase):
    def test_manifest_pins_entry_and_semantic_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(manifest["classification"], "fortad-semantic-mismatch-with-bounded-forward-port")
        self.assertEqual(manifest["upstream_entry_point"], "sub0(x,y,z)")
        self.assertEqual(manifest["ported_entry_point"], "set01_lh050(x,y,z)")
        self.assertIn("nonRegressions/set01/lh050/program_b.f", manifest["upstream_sources"])

    def test_independent_python_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_exact_fresh_and_bounded_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: fortad-semantic-mismatch-with-bounded-forward-port",
            "upstream_exact_strict_compile: program=0 tangent=0 reverse=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=1",
            "fortad_exact_generation: forward=pass reverse=pass",
            "fortad_exact_independent_oracle: forward=mismatch reverse=mismatch",
            "fortad_bounded_forward: generation=pass strict_compile=0 runtime=pass",
            "fortad_bounded_reverse: generation=pass strict_compile=1",
            "exact_forward_oracle: mismatch",
            "exact_reverse_oracle: mismatch",
            "bounded_forward_oracle: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
