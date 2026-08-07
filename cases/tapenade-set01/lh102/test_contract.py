#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the lh102 evidence package."""

from __future__ import annotations

import subprocess
import sys
import tomllib
import unittest
from pathlib import Path

CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = BENCH / "upstream" / "tapenade" / "nonRegressions" / "set01" / "lh102"


class Lh102ContractTests(unittest.TestCase):
    def test_pinned_source_and_entry_point(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1")
        case = manifest["case"][0]
        self.assertEqual(case["upstream_entry_point"], "testprotect(xx,yy,zz,vv1,vv2,vv3)")
        source = (UPSTREAM / "program.f").read_text()
        self.assertIn("SUBROUTINE TESTPROTECT", source)
        self.assertIn("tmpX**tmpY", source)

    def test_independent_three_behavior_oracle(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_behavioral_cases: 3", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_runner_record_contains_all_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: transformable-upstream-fortad-output-gap",
            "upstream_strict_compile: program.f=0 program_b.f=0 program_d.f=0",
            "tapenade_generation: parser=0 forward=0 reverse=0",
            "fortad_check: status=0",
            "fortad_jvp: status=0",
            "fortad_vjp: status=0",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
