#!/usr/bin/env python3
"""Contract and independent-oracle checks for case-local lh042 evidence."""

from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = CASE.parents[2] / "upstream" / "tapenade" / "nonRegressions" / "set01" / "lh042"


class Lh042ContractTests(unittest.TestCase):
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
        self.assertEqual(manifest["upstream_entry_point"], "decls1(t1,t2,t3,n,m,t4,t5)")
        self.assertEqual(
            manifest["upstream_sources"],
            [
                "nonRegressions/set01/lh042/program.f",
                "nonRegressions/set01/lh042/program_d.f",
                "nonRegressions/set01/lh042/program_b.f",
                "nonRegressions/set01/lh042/program_dv.f",
                "nonRegressions/set01/lh042/program_p.f",
            ],
        )

    def test_independent_compiler_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_program.f: expected-refusal", completed.stdout)
        self.assertIn("oracle_program_dv.f: expected-refusal", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_records_all_generation_and_refusal_gates(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "entry_point: decls1(t1,t2,t3,n,m,t4,t5)",
            "upstream_program.f_strict_compile: expected-refusal",
            "upstream_program_dv.f_strict_compile: expected-refusal",
            "tapenade_generation: parser=pass forward=pass reverse=pass multidirectional=pass",
            "tapenade_fresh_strict_compile: parser=expected-refusal forward=expected-refusal reverse=expected-refusal multidirectional=expected-refusal",
            "fortad_forward: expected-refusal parse declaration-order line 10",
            "fortad_reverse: expected-refusal parse declaration-order line 10",
            "oracle_status: pass",
            "closure: no standard-conforming port or support claim",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main()
