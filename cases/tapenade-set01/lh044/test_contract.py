#!/usr/bin/env python3
"""Contract checks for the case-local lh044 invalid-upstream evidence."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = CASE.parents[2] / "upstream" / "tapenade" / "nonRegressions" / "set01" / "lh044"


class Lh044ContractTests(unittest.TestCase):
    def test_manifest_preserves_pins_and_invalid_closure(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "db0050259520b618e2a0aeba203c85a7613943b5",
        )
        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["source_form"], "fixed")
        self.assertEqual(manifest["source_harness"], "cases/tapenade-set01/lh044/harness.f")
        self.assertIn(
            "nonRegressions/set01/lh044/program_dv.f",
            manifest["upstream_sources"],
        )

    def test_independent_compiler_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_fresh_and_exact_engine_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_program.f_strict_compile: expected-refusal",
            "upstream_program_dv.f_strict_compile: expected-refusal",
            "source_harness: expected-refusal diagnostic=FX1-intrinsic-dummy",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_generated_strict_compile: parser=expected-refusal tangent=expected-refusal reverse=expected-refusal",
            "fortad_forward: expected-refusal",
            "fortad_reverse: expected-refusal",
            "independent_oracle: strict compiler rejection identity",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
