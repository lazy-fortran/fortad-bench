#!/usr/bin/env python3
"""Behavioral and evidence-contract tests for bounded lh069."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM = ROOT / "upstream" / "tapenade" / "nonRegressions" / "set01" / "lh069"


class Lh069ContractTests(unittest.TestCase):
    def test_manifest_pins_boundary_and_port(self) -> None:
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
            manifest["classification"],
            "expected-refusal-with-bounded-forward-port",
        )
        self.assertEqual(manifest["upstream_entry_point"], "loop2(a,b)")
        self.assertIn("uninitialized local n", manifest["dependencies"])

    def test_independent_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        for marker in (
            "numeric_hand_jvp: pass",
            "numeric_hand_vjp: pass",
            "finite_difference: pass",
            "adjoint_identity: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, completed.stdout)

    def test_result_records_all_engine_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "upstream_exact_strict_compile: program=0 parser=0 tangent=0 reverse=0 multidirectional=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward_strict_compile: 0",
            "fortad_bounded_reverse_strict_compile: ao7=0 bo5=0",
            "bounded_port_precondition: n=10",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
