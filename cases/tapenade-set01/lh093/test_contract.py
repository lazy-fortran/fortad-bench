#!/usr/bin/env python3
"""Three behavioral contracts for the exact-source lh093 boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade")))
FORTAD = Path(os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad"))
SOURCE = UPSTREAM / "nonRegressions" / "set01" / "lh093"
STRICT_FIXED = ["-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface"]
LEGACY_FIXED = ["-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra", "-Wimplicit-interface"]
STRICT_FREE = ["-std=f2018", "-ffree-form", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface"]
LEGACY_FREE = ["-std=legacy", "-ffree-form", "-Wall", "-Wextra", "-Wimplicit-interface"]


class Lh093ContractTests(unittest.TestCase):
    def test_independent_semantic_oracle(self) -> None:
        completed = subprocess.run(["python3", str(CASE / "oracle.py"), str(SOURCE)], capture_output=True, text=True, check=False)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_source_inventory: pass", completed.stdout)
        self.assertIn("oracle_jvp_finite_difference: pass", completed.stdout)
        self.assertIn("oracle_vjp_adjoint_identity: pass", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_generation_and_compiler_boundary(self) -> None:
        tapenade = UPSTREAM / "bin" / "tapenade"
        self.assertTrue(tapenade.is_file())
        with tempfile.TemporaryDirectory(prefix="lh093-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, option, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                output = work / mode
                output.mkdir()
                command = [str(tapenade), option]
                if mode != "parser":
                    command += ["-root", "testIOmess"]
                command += ["-O", str(output), "-o", "lh093", str(SOURCE / "program.f")]
                generated = subprocess.run(command, capture_output=True, text=True, check=False)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"lh093_{suffix}.f90"
                self.assertTrue(source.is_file())
                legacy = subprocess.run(["gfortran", *LEGACY_FREE, "-c", str(source), "-o", str(work / f"{suffix}-legacy.o")], capture_output=True, text=True, check=False)
                strict = subprocess.run(["gfortran", *STRICT_FREE, "-fsyntax-only", str(source)], capture_output=True, text=True, check=False)
                self.assertEqual(legacy.returncode, 0, legacy.stdout + legacy.stderr)
                self.assertNotEqual(strict.returncode, 0)
                self.assertIn("comma before i/o item list", strict.stdout.lower() + strict.stderr.lower())

    def test_fortad_exact_check_forward_reverse_boundary(self) -> None:
        fortad = FORTAD / "build" / "fo" / "bin" / "fortad"
        self.assertTrue(fortad.is_file())
        with tempfile.TemporaryDirectory(prefix="lh093-contract-fortad-") as temporary:
            work = Path(temporary)
            commands = {
                "check": [str(fortad), "check", "--output", str(work / "check.f90"), str(SOURCE / "program.f")],
                "forward": [str(fortad), "--mode", "forward", "--indep", "a,b,d", "--dep", "b,c,d,e", "--proc", "testIOmess", "--name", "lh093_jvp", "--module", "lh093_jvp_mod", "--output", str(work / "forward.f90"), str(SOURCE / "program.f")],
                "reverse": [str(fortad), "--mode", "reverse", "--indep", "a,b,d", "--dep", "b,c,d,e", "--proc", "testIOmess", "--name", "lh093_vjp", "--module", "lh093_vjp_mod", "--output", str(work / "reverse.f90"), str(SOURCE / "program.f")],
            }
            for mode, command in commands.items():
                completed = subprocess.run(command, capture_output=True, text=True, check=False)
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn("unsupported statement at line 8", completed.stdout + completed.stderr)
                self.assertFalse((work / f"{mode}.f90").exists())


if __name__ == "__main__":
    unittest.main()
