#!/usr/bin/env python3
"""Evidence-contract checks for the exact set02/lh198 refusal record."""

from __future__ import annotations

import csv
import hashlib
import os
import subprocess
import sys
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
).resolve()


class Lh198ContractTests(unittest.TestCase):
    def test_manifest_pins_exact_source_and_classification(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-fortad-common-block-call-boundary",
        )
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "ac045ebd44281ae559d1279fdfe7370a97a74a47",
        )
        for relative, digest in manifest["upstream_sha256"].items():
            path = UPSTREAM_ROOT / relative
            self.assertTrue(path.is_file(), path)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest, relative)

    def test_independent_oracle_is_behavioral(self) -> None:
        source = UPSTREAM_ROOT / "nonRegressions" / "set02" / "lh198" / "program.f"
        completed = subprocess.run(
            [sys.executable, str(CASE / "oracle.py"), str(source)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        for marker in (
            "oracle_semantics: top COMMON-block dataflow",
            "finite_difference_max_error:",
            "adjoint_identity_max_error:",
            "oracle_status: pass",
        ):
            self.assertIn(marker, completed.stdout)

    def test_result_and_ledger_record_a_deliberate_refusal(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-fortad-common-block-call-boundary",
            "upstream_exact_strict_compile: program=0 program_b=0 program_d=0 program_p=0",
            "upstream_exact_legacy_compile: program=0 program_b=0 program_d=0 program_p=0",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_legacy_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_behavior: check=pass",
            "forward=expected-refusal",
            "reverse=expected-refusal",
            "no_repaired_port: true",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        with (BENCH / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["nonRegressions/set02/lh198"]
        self.assertEqual(row["status"], "expected-refusal")
        self.assertEqual(row["entry_point"], "top(x,y)")
        self.assertEqual(
            row["tapenade_result"],
            "pass-fresh-parser-tangent-reverse-generation-strict-and-legacy-compile-pass",
        )
        self.assertEqual(
            row["fortad_result"],
            "expected-refusal-exact-forward-reverse-no-derivative-rule-AAA-no-output",
        )
        queue = (BENCH / "docs/corpora/tapenade-fortran-queue.jsonl").read_text()
        self.assertNotIn("nonRegressions/set02/lh198", queue)


if __name__ == "__main__":
    unittest.main()
