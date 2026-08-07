#!/usr/bin/env python3
"""Contract checks for the pinned set05/v069 invalid-upstream evidence."""

from __future__ import annotations

import csv
import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CASE = ROOT / "cases/tapenade-set05"
UPSTREAM_REVISION = "e59864cab441d4175df75383b3ff58c3dcd26df9"
FORTAD_REVISION = "a41afdec1502e0399a145f7e68728e0cc6c1d915"


class V069ClosureTests(unittest.TestCase):
    def test_result_records_all_boundaries(self) -> None:
        report = (CASE / "v069_result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: unsupported-invalid-upstream-fortran",
            "upstream_exact_strict_compile: program.f90=1 program_d.f90=1",
            "upstream_exact_legacy_compile: program.f90=1 program_d.f90=1",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=1 tangent=1 reverse=1",
            "tapenade_fresh_legacy_compile: parser=1 tangent=1 reverse=1",
            "fortad_parser: expected-refusal",
            "fortad_forward: expected-refusal",
            "fortad_reverse: expected-refusal",
            "oracle_status: pass",
            "exact_source_sha256:",
            "stored_source_sha256:",
            "fresh_tapenade_sha256:",
        ):
            self.assertIn(marker, report)

    def test_manifest_pins_exact_sources_and_classification(self) -> None:
        with (CASE / "v069_manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], UPSTREAM_REVISION)
        self.assertEqual(manifest["fortad_revision"], FORTAD_REVISION)
        self.assertEqual(manifest["classification"], "unsupported-invalid-upstream-fortran")
        self.assertEqual(
            manifest["upstream_sha256"]["nonRegressions/set05/v069/program.f90"],
            "8f3cb22e9113988b18cab478b6ee4e36df0eeda8e064ca4b715d8515acf66236",
        )
        self.assertIn("nonRegressions/set05/v069/program_d.f90", manifest["stored_references"])

    def test_ledger_closes_only_v069(self) -> None:
        with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        self.assertEqual(rows["nonRegressions/set05/v069"]["status"], "unsupported-invalid-upstream-fortran")
        self.assertEqual(
            rows["nonRegressions/set05/v069"]["fortad_result"],
            "expected-refusal-exact-parser-forward-reverse-no-output",
        )
        self.assertEqual(rows["nonRegressions/set05/v070"]["status"], "untriaged")

    def test_independent_oracle_passes_against_pinned_checkout(self) -> None:
        upstream = Path(
            os.environ.get(
                "TAPENADE_REPO",
                "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade",
            )
        )
        completed = subprocess.run(
            ["python3", str(CASE / "v069_oracle.py"), str(upstream / "nonRegressions/set05/v069")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_manifest_source_hashes_match_pinned_checkout(self) -> None:
        with (CASE / "v069_manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        upstream = Path(
            os.environ.get(
                "TAPENADE_REPO",
                "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade",
            )
        )
        for relative, expected in manifest["upstream_sha256"].items():
            digest = hashlib.sha256((upstream / relative).read_bytes()).hexdigest()
            self.assertEqual(digest, expected, relative)


if __name__ == "__main__":
    unittest.main(verbosity=1)
