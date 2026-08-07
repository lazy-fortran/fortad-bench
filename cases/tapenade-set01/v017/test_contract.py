#!/usr/bin/env python3
"""Three behavioral contracts for the v017 no-entry-point case."""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set04" / "v017"
STRICT_FLAGS = [
    "-std=f2018",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-cpp",
]


class V017ContractTests(unittest.TestCase):
    def test_independent_module_declaration_semantic_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn(
            "oracle_common_layout: /vars/ contains ff(100) and bval",
            completed.stdout,
        )
        self.assertIn("oracle_executable_units: 0", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_strict_compiler_primal_acceptance_and_stored_parser_refusal(self) -> None:
        compiler = os.environ.get("FC", "gfortran")
        out_dir = Path(
            subprocess.check_output(
                ["mktemp", "-d", "/var/tmp/v017-contract.XXXXXX"],
                text=True,
            ).strip()
        )
        try:
            primal = subprocess.run(
                [
                    compiler,
                    *STRICT_FLAGS,
                    "-J",
                    str(out_dir),
                    "-I",
                    str(out_dir),
                    "-c",
                    str(SOURCE_DIR / "program.f90"),
                    "-o",
                    str(out_dir / "primal.o"),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            stored = subprocess.run(
                [
                    compiler,
                    *STRICT_FLAGS,
                    "-J",
                    str(out_dir),
                    "-I",
                    str(out_dir),
                    "-c",
                    str(SOURCE_DIR / "program_p.f90"),
                    "-o",
                    str(out_dir / "stored.o"),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(primal.returncode, 0, primal.stdout + primal.stderr)
            self.assertNotEqual(stored.returncode, 0, stored.stdout + stored.stderr)
            self.assertIn("SEQUENCE PRIVATE", stored.stdout + stored.stderr)
        finally:
            subprocess.run(["rm", "-rf", str(out_dir)], check=True)

    def test_no_entry_point_has_no_numerical_observable_boundary(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn(
            "oracle_numerical_observable: undefined-no-entry-point",
            completed.stdout,
        )
        self.assertNotIn("oracle_entry_point:", completed.stdout)


if __name__ == "__main__":
    unittest.main()
