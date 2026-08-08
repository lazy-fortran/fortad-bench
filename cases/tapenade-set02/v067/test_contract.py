#!/usr/bin/env python3
"""Contract and independent semantic checks for the exact v067 boundary."""

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
SOURCE_DIR = UPSTREAM_ROOT / "nonRegressions" / "set02" / "v067"


class V067ContractTests(unittest.TestCase):
    def test_manifest_pins_exact_sources_and_valid_source_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-valid-source-tapenade-and-fortad-boundary")
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "19e8cda7ad71990339f9ed254cc40128fcbff364")
        self.assertEqual(manifest["source_form"], "fixed")
        for relative, digest in manifest["upstream_sha256"].items():
            path = UPSTREAM_ROOT / relative
            self.assertTrue(path.is_file(), path)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest, relative)
        self.assertIn("not an invalid-source claim", " ".join(manifest["dependencies"]))

    def test_independent_analytical_finite_difference_adjoint_oracle(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(CASE / "oracle.py"), str(SOURCE_DIR)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        for marker in (
            "oracle_semantics: T(Y) = Y + pi",
            "finite_difference_max_error:",
            "adjoint_identity_max_error:",
            "oracle_status: pass",
        ):
            self.assertIn(marker, completed.stdout)

    def test_result_ledger_and_queue_record_exact_boundary(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-valid-source-tapenade-and-fortad-boundary",
            "upstream_exact_strict_compile: program.f=0 program_p.f=0",
            "upstream_exact_legacy_compile: program.f=0 program_p.f=0",
            "tapenade_exact_generation: parser=0 tangent=0 reverse=0",
            "tapenade_exact_products: parser=none tangent=none reverse=none",
            "unit ADJ_FCN not found",
            "fortad_exact_parser: pass",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "no_repaired_port: true",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        with (BENCH / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["nonRegressions/set02/v067"]
        self.assertEqual(row["status"], "expected-refusal")
        self.assertEqual(row["entry_point"], "ADJ_FCN(T,Y,YP,RESULT,RP)")
        self.assertEqual(row["tapenade_result"], "expected-refusal-exact-source-cr-only-line-terminator-no-root")
        self.assertEqual(row["fortad_result"], "expected-refusal-exact-forward-empty-stub-reverse-assignment-boundary")
        queue = (BENCH / "docs/corpora/tapenade-fortran-queue.jsonl").read_text()
        self.assertNotIn('"path":"nonRegressions/set02/v067"', queue)


if __name__ == "__main__":
    unittest.main(verbosity=1)
