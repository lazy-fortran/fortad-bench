#!/usr/bin/env python3
"""Three behavioral contract tests for the v421 boundary case."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent


def report() -> str:
    return (CASE / "result.txt").read_text(encoding="utf-8")


class V421ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_strict_compile_boundary(self) -> None:
        text = report()
        self.assertIn("upstream_exact_strict_compile: primal=1 stored_program_Rd=1", text)
        self.assertIn("exact_primal_diagnostic: actual-argument-contains-too-few-elements", text)
        self.assertIn("stored_program_Rd_diagnostic: actual-argument-contains-too-few-elements", text)

    def test_fresh_tapenade_generation_and_strict_compile_boundary(self) -> None:
        text = report()
        self.assertIn("tapenade_generation: parser=0 tangent=0 reverse=0", text)
        self.assertIn("tapenade_fresh_strict_compile: parser=1 tangent=1 reverse=1", text)
        self.assertIn("fresh_sources: parser=v421_p.f90 tangent=v421_d.f90 reverse=v421_b.f90", text)

    def test_fortad_refusal_and_independent_oracle(self) -> None:
        text = report()
        self.assertIn(
            'fortad_exact_parser: expected-refusal status=1 output=none diagnostic="unsupported expression at line 14"',
            text,
        )
        self.assertIn(
            'fortad_exact_forward: expected-refusal status=1 output=none diagnostic="unsupported expression at line 14"',
            text,
        )
        self.assertIn(
            'fortad_exact_reverse: expected-refusal status=1 output=none diagnostic="unsupported expression at line 14"',
            text,
        )
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass invalid-top-actual-shape", completed.stdout)


if __name__ == "__main__":
    unittest.main()
