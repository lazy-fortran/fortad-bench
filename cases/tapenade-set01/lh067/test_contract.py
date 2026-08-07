#!/usr/bin/env python3
"""Contract and independent behavioral checks for the lh067 evidence."""

from __future__ import annotations

import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
default_upstream = CASE.parents[2] / "upstream" / "tapenade"
if not default_upstream.is_dir():
    default_upstream = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(default_upstream)))
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh067"


class Lh067ContractTests(unittest.TestCase):
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
        self.assertEqual(manifest["upstream_entry_point"], "read7(z)")
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-with-bounded-forward-port",
        )
        self.assertIn("nonRegressions/set01/lh067/program_dv.f", manifest["upstream_sources"])
        self.assertIn("normal-read-path", manifest["closure"])

    def test_independent_oracle_is_behavioral(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertIn("fd_error:", completed.stdout)
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
            "upstream_exact_strict_compile: primal=0 parser_reference=1 tangent=1 reverse=1 multidirectional=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=1 tangent=1 reverse=1",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward: pass-transform-compile-runtime",
            "fortad_bounded_reverse: pass-transform-compile-runtime",
            "bounded_scope: successful-read path",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
