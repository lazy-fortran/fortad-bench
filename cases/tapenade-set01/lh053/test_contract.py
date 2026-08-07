#!/usr/bin/env python3
"""Behavioral and evidence-contract checks for the lh053 case."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
import os
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(CASE.parents[2] / "upstream" / "tapenade")))
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh053"


class Lh053ContractTests(unittest.TestCase):
    def test_manifest_pins_entry_and_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "db0050259520b618e2a0aeba203c85a7613943b5")
        case = manifest["case"][0]
        self.assertEqual(case["upstream_entry_point"], "cg12v4(z,tk,gamai,v,w,g,tau,ncmax)")
        self.assertEqual(case["classification"], "expected-refusal-with-bounded-forward-port")
        self.assertIn("nonRegressions/set01/lh053/program_dv.f", case["upstream_sources"])

    def test_independent_oracle_is_behavioral(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertIn("fd_error:", completed.stdout)
        self.assertIn("adjoint_identity_residual:", completed.stdout)

    def test_sources_and_result_contract(self) -> None:
        for name in ("program.f", "program_p.f", "program_d.f", "program_b.f", "program_dv.f"):
            self.assertTrue((UPSTREAM / name).is_file(), name)
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_parser_strict_compile: expected-refusal",
            "tapenade_forward_strict_compile: expected-refusal",
            "tapenade_reverse_strict_compile: expected-refusal",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_port_forward: pass-transform-compile-runtime",
            "fortad_port_reverse: expected-refusal",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
