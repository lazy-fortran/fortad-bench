#!/usr/bin/env python3
"""Contract and behavioral checks for the case-local lh021 evidence."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


class Lh021ContractTests(unittest.TestCase):
    def test_manifest_records_pins_and_refusal_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        case = manifest["case"][0]
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "db0050259520b618e2a0aeba203c85a7613943b5",
        )
        self.assertEqual(case["classification"], "expected-refusal")
        self.assertIn("program_b.f", case["stored_references"])

    def test_independent_compiler_oracle(self) -> None:
        upstream = CASE.parents[2] / "upstream" / "tapenade" / "nonRegressions" / "set01" / "lh021"
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(upstream)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_all_engine_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal",
            "tapenade_parser_strict_compile: pass",
            "tapenade_forward_strict_compile: pass",
            "tapenade_reverse_strict_compile: expected-refusal",
            "fortad_forward: expected-refusal at line 5",
            "fortad_reverse: expected-refusal at line 5",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
