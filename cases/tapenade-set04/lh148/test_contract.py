#!/usr/bin/env python3
"""Contract checks for the promoted shard-0 set04/lh148 entry point."""

from __future__ import annotations

import subprocess
import sys
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


class Lh148Contract(unittest.TestCase):
    def test_manifest_pins_both_revisions_and_source(self) -> None:
        manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "7f56c371e22b5c8e6cc953b4f19b94df90f6ab06")
        self.assertEqual(manifest["upstream_entry_point"], "toto(a,b,c,d)")
        self.assertEqual(manifest["classification"], "runnable-ported")

    def test_independent_oracle_passes(self) -> None:
        oracle = subprocess.run(
            [sys.executable, str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_behavioral_cases: 4", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)

    def test_result_records_full_evidence(self) -> None:
        result = (CASE / "result.txt").read_text(encoding="utf-8")
        self.assertIn("classification: runnable-ported", result)
        self.assertIn("tapenade_modes: parser forward reverse", result)
        self.assertIn("fortad_modes: forward reverse", result)
        self.assertIn("oracle_status: pass", result)


if __name__ == "__main__":
    raise SystemExit(unittest.main())
