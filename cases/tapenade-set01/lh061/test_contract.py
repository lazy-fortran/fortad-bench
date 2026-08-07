#!/usr/bin/env python3
"""Contract and independent behavioral checks for the lh061 evidence."""

from __future__ import annotations

import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = Path(
    os.environ.get(
        "TAPENADE_REPO",
        str(CASE.parents[2] / "upstream" / "tapenade"),
    )
) / "nonRegressions" / "set01" / "lh061"


class Lh061ContractTests(unittest.TestCase):
    def test_manifest_preserves_pins_and_callback_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "0e156041c1f92736c1e35f8164b37992c4c8d780",
        )
        self.assertEqual(manifest["classification"], "expected-refusal")
        self.assertIn("nonRegressions/set01/lh061/program_dv.f", manifest["upstream_sources"])
        self.assertIn("PJAC", manifest["dependencies"])

    def test_independent_compiler_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertIn("missing-DIFFSIZES.inc", completed.stdout)

    def test_result_records_all_engine_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal",
            "upstream_exact_source_strict_compile: pass",
            "upstream_stored_reverse_strict_compile: pass",
            "upstream_stored_multidirectional_strict_compile: expected-refusal",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_generated_strict_compile: parser=pass tangent=pass reverse=pass",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "no_bounded_numerical_port: unresolved-callback-semantics",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
