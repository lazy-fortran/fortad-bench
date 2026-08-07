#!/usr/bin/env python3
"""Contract and independent behavioral checks for the lh035 closure."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]


class Lh035ContractTests(unittest.TestCase):
    def test_manifest_pins_invalid_source_boundary(self) -> None:
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
        self.assertEqual(case["classification"], "unsupported-invalid-upstream-fortran")
        self.assertEqual(case["stored_references"], ["program_p.f", "program_p.msg"])

    def test_independent_compiler_oracle(self) -> None:
        upstream = (
            ROOT
            / "upstream"
            / "tapenade"
            / "nonRegressions"
            / "set01"
            / "lh035"
        )
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(upstream)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_all_required_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: unsupported-invalid-upstream-fortran",
            "upstream_exact_strict_compile: expected-refusal",
            "upstream_stored_parser_strict_compile: expected-refusal",
            "tapenade_parser_generation: pass",
            "tapenade_forward_generation: pass",
            "tapenade_reverse_generation: pass",
            "tapenade_parser_strict_compile: expected-refusal",
            "tapenade_forward_strict_compile: expected-refusal",
            "tapenade_reverse_strict_compile: expected-refusal",
            "stored_program_p_msg: DD02 DD01 TC16",
            "fortad_forward: expected-refusal",
            "fortad_reverse: expected-refusal",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
