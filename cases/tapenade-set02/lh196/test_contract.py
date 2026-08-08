#!/usr/bin/env python3
"""Evidence-contract checks for the exact set02/lh196 boundary."""

from __future__ import annotations

import csv
import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
).resolve()


class Lh196ContractTests(unittest.TestCase):
    def test_manifest_pins_exact_boundary_and_hashes(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-fortad-function-inlining-real8-boundary",
        )
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "ac8d04be7303bbd3b6bd9f865074401b5041b9af",
        )
        for relative, digest in manifest["upstream_sha256"].items():
            path = UPSTREAM_ROOT / relative
            self.assertTrue(path.is_file(), path)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest, relative)

    def test_independent_oracle_is_behavioral(self) -> None:
        source = UPSTREAM_ROOT / "nonRegressions" / "set02" / "lh196" / "program.f"
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(source)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        for marker in (
            "oracle_semantics: polygon perimeter-squared over signed area",
            "finite_difference_max_error:",
            "adjoint_identity_max_error:",
            "oracle_status: pass",
        ):
            self.assertIn(marker, completed.stdout)

    def test_result_and_ledger_close_only_lh196(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-fortad-function-inlining-real8-boundary",
            "upstream_exact_strict_compile: program=1 program_b=1 program_d=1 diagnostic=REAL8",
            "upstream_exact_legacy_compile: program=0 program_b=0 program_d=0",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=1 tangent=1 reverse=1 diagnostic=REAL8",
            "tapenade_fresh_legacy_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_behavior: check=expected-refusal",
            "no_repaired_port: true",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        with (BENCH / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["nonRegressions/set02/lh196"]
        self.assertEqual(row["status"], "expected-refusal")
        self.assertEqual(row["entry_point"], "POLYCOST(X,Y,ns)")
        self.assertEqual(
            row["tapenade_result"],
            "pass-fresh-parser-tangent-reverse-generation-strict-REAL8-refusal-legacy-compile-pass",
        )
        self.assertEqual(
            row["fortad_result"],
            "expected-refusal-exact-check-forward-reverse-function-inlining-no-output",
        )


if __name__ == "__main__":
    unittest.main()
