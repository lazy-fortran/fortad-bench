#!/usr/bin/env python3
"""Contract and independent behavioral checks for the lh064 evidence."""

from __future__ import annotations

import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = Path(
    os.environ.get(
        "TAPENADE_REPO",
        str(CASE.parents[2] / "upstream" / "tapenade"),
    )
) / "nonRegressions" / "set01" / "lh064"


class Lh064ContractTests(unittest.TestCase):
    def test_manifest_preserves_pins_and_bounded_boundary(self) -> None:
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
        self.assertEqual(manifest["upstream_entry_point"], "cg02v1(T,n); truc(a)")
        self.assertIn("nonRegressions/set01/lh064/program_b.f", manifest["upstream_sources"])
        self.assertIn("INTEGER*4", manifest["dependencies"])

    def test_independent_python_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertIn("adjoint_identity_residual", completed.stdout)

    def test_result_records_all_engine_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "upstream_exact_strict_compile: program=1 parser=0 tangent=0 reverse=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=1",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward: pass-transform-compile-runtime",
            "fortad_bounded_reverse: expected-refusal",
            "fortad_bounded_forward_strict_compile: 0",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
