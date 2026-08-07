#!/usr/bin/env python3
"""Contract checks for the exact set02/lh163 tranche."""

from __future__ import annotations

import subprocess
import sys
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]


class Lh163Contract(unittest.TestCase):
    def test_manifest_is_pinned_and_independent_oracle_passes(self) -> None:
        manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "a1c9f25f87eaadf700ba47ee3e841a0fb41585a3")
        self.assertEqual(manifest["dependent"], "s")
        oracle = subprocess.run(
            [sys.executable, str(CASE / "oracle.py"), str(CASE / "program.f")],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_behavioral_cases: 3", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)

    def test_runner_result_records_all_three_modes(self) -> None:
        result = (CASE / "result.txt").read_text(encoding="utf-8")
        self.assertIn("classification: runnable-ported", result)
        self.assertIn("tapenade_modes: parser forward reverse", result)
        self.assertIn("fortad_modes: parser forward reverse", result)
        self.assertIn("oracle_status: pass", result)


if __name__ == "__main__":
    unittest.main()
