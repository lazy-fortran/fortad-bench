#!/usr/bin/env python3
"""Contract and independent-oracle checks for case-local lh056 evidence."""

from __future__ import annotations

import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(CASE.parents[2] / "upstream" / "tapenade"))
)
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh056"


class Lh056ContractTests(unittest.TestCase):
    def test_manifest_preserves_pins_and_invalid_closure(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "0e156041c1f92736c1e35f8164b37992c4c8d780")
        self.assertEqual(manifest["source_form"], "fixed")
        case = manifest["case"][0]
        self.assertEqual(case["classification"], "unsupported-invalid-upstream-fortran")
        self.assertEqual(case["upstream_entry_point"], "f(t)")
        self.assertTrue(any(source.endswith("/program_dv.f") for source in case["upstream_sources"]))
        self.assertIn("DIFFSIZES.inc", " ".join(case["dependencies"]))

    def test_independent_compiler_oracle_is_behavioral(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_program.f: status=1", completed.stdout)
        self.assertIn("oracle_program_d.f: status=0", completed.stdout)
        self.assertIn("oracle_program_dv.f: status=1", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_mixed_compile_and_refusal_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: unsupported-invalid-upstream-fortran",
            "entry_point: f(t)",
            "upstream_program.f_strict_compile: expected-refusal",
            "upstream_program_d.f_strict_compile: pass",
            "upstream_program_b.f_strict_compile: pass",
            "upstream_program_dv.f_strict_compile: expected-refusal",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_parser_strict_compile: expected-refusal",
            "tapenade_forward_strict_compile: pass",
            "tapenade_reverse_strict_compile: pass",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_port: not-applicable-invalid-upstream",
            "oracle_status: pass",
            "closure: no bounded port or exact-support claim",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
