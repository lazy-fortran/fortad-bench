#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned lh000 boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get(
        "TAPENADE_REPO",
        str(BENCH / "upstream" / "tapenade")
        if (BENCH / "upstream" / "tapenade").is_dir()
        else "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade",
    )
)
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh000"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"


class Lh000ContractTests(unittest.TestCase):
    def test_empty_source_and_stored_refusals_are_pinned(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-no-entry-point")
        self.assertEqual(manifest["upstream_entry_point"], "none (program.f and program.f90 are empty)")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        for name in ("program.f", "program.f90"):
            self.assertEqual((UPSTREAM / name).read_bytes(), b"", name)
        refusal = (
            "1 Command: No root unit to differentiate\n"
            "2 File: The code provided does not contain a top procedure\n"
        )
        for name in ("program_b.msg", "program_bv.msg", "program_d.msg", "program_db.msg", "program_dv.msg"):
            self.assertEqual((UPSTREAM / name).read_text(encoding="utf-8"), refusal, name)

    def test_independent_semantic_oracle_reproduces_no_entry_shape(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_entry_point: none", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_fresh_engine_boundaries_without_a_port(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-no-entry-point",
            "upstream_exact_strict_compile: program.f=0 program.f90=0",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_sources: parser=none tangent=none reverse=none",
            "tapenade_tangent_reverse_diagnostic: no-root-unit-and-no-top-procedure",
            "fortad_exact_parser: not-applicable-no-entry-point",
            "fortad_exact_forward: not-applicable-no-entry-point",
            "fortad_exact_reverse: not-applicable-no-entry-point",
            "port_result: not-claimed reason=empty-source-has-no-procedure-interface",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            hashlib.sha256((UPSTREAM / "program.f").read_bytes()).hexdigest(),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        )


if __name__ == "__main__":
    unittest.main(verbosity=1)
