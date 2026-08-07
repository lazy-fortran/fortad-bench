#!/usr/bin/env python3
"""Behavioral and evidence-contract checks for the isolated lh047 case."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


class Lh047ContractTests(unittest.TestCase):
    def test_manifest_records_pins_boundary_and_modes(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "db0050259520b618e2a0aeba203c85a7613943b5")
        self.assertEqual(manifest["classification"], "expected-refusal-with-bounded-forward-port")
        self.assertEqual(manifest["upstream_entry_point"], "adj13bis(u,z,t); sub1(u,y2,z,v)")
        self.assertIn("exact-forward:refused", manifest["modes"])
        self.assertIn("bounded-reverse:refused", manifest["modes"])

    def test_independent_oracle_is_behavioral(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_all_engine_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "entry_point: adj13bis(u,z,t); sub1(u,y2,z,v)",
            "upstream_exact_strict_compile: program=0 tangent=0 reverse=0",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward: generation=pass strict_compile=0",
            "fortad_bounded_reverse: generation=pass strict_compile=expected-refusal",
            "fd_errors:",
            "adjoint_residual:",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        self.assertIn("unsupported statement at line 5", report)
        self.assertIn("dependent seed t_b has INTENT(IN)", report)


if __name__ == "__main__":
    unittest.main()
