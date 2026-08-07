#!/usr/bin/env python3
"""Exactly three behavioral contract tests for lh098."""

from __future__ import annotations

import hashlib
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
SOURCE = UPSTREAM / "nonRegressions" / "set01" / "lh098"


class Lh098ContractTests(unittest.TestCase):
    def test_manifest_and_exact_upstream_are_pinned(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1")
        self.assertEqual(manifest["upstream_entry_point"], "ff(N,t,xbt,x)")
        self.assertEqual(manifest["classification"], "runnable-exact-source-no-port")
        self.assertIn(b"subroutine ff(N,t,xbt,x)", SOURCE.joinpath("program.f").read_bytes())
        self.assertEqual(hashlib.sha256(SOURCE.joinpath("program.f").read_bytes()).hexdigest(),
                         "82207bcfcc4c9404e11c5e6195550fea8f4271ad884ad3a73a4b8713d79439f2")

    def test_independent_oracle_checks_jvp_vjp_behavior(self) -> None:
        completed = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_central_difference_residual:", completed.stdout)
        self.assertIn("oracle_adjoint_identity: pass", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_all_runner_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "upstream_exact_strict_compile: pass",
            "upstream_exact_legacy_compile: pass",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_legacy_compile: parser=pass tangent=pass reverse=pass",
            "fortad_exact_parser_check: pass",
            "fortad_exact_jvp: pass",
            "fortad_exact_vjp: pass",
            "fortad_generated_strict_compile: check=expected-refusal",
            "fortad_generated_legacy_compile: check=expected-refusal",
            "port_result: not-created exact-source-preserved",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main(verbosity=1)
