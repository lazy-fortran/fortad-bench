#!/usr/bin/env python3
"""Exactly three independent behavioral contracts for lh097."""
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
SOURCE = UPSTREAM / "nonRegressions" / "set01" / "lh097"
STRICT = ["-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface"]
LEGACY = ["-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only", "-Wall", "-Wextra", "-Wimplicit-interface"]

class Lh097ContractTests(unittest.TestCase):
    def test_independent_semantic_oracle(self) -> None:
        completed = subprocess.run(["python3", str(CASE / "oracle.py"), str(SOURCE)], capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_tangent: fixed-read-value JVP agrees", completed.stdout)
        self.assertIn("oracle_reverse: fixed-read-value VJP passes", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_generation_and_gates(self) -> None:
        tapenade = UPSTREAM / "bin" / "tapenade"
        self.assertTrue(tapenade.is_file())
        with tempfile.TemporaryDirectory(prefix="lh097-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode in ("p", "d", "b"):
                output = work / mode; output.mkdir()
                generated = subprocess.run([str(tapenade), f"-{mode}", "-root", "testiotbr", "-O", str(output), "-o", "lh097", str(SOURCE / "program.f")], capture_output=True, text=True)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"lh097_{mode}.f"; self.assertTrue(source.is_file())
                legacy = subprocess.run(["gfortran", *LEGACY, str(source)], capture_output=True, text=True)
                self.assertEqual(legacy.returncode, 0, legacy.stdout + legacy.stderr)
                strict = subprocess.run(["gfortran", *STRICT, str(source)], capture_output=True, text=True)
                self.assertNotEqual(strict.returncode, 0); self.assertIn("Comma before i/o item list", strict.stderr)

    def test_fortad_exact_three_mode_refusal(self) -> None:
        fortad = FORTAD / "build" / "fo" / "bin" / "fortad"; self.assertTrue(fortad.is_file())
        with tempfile.TemporaryDirectory(prefix="lh097-contract-fortad-") as temporary:
            work = Path(temporary)
            commands = (
                [str(fortad), "check", "--output", str(work / "check.f90"), str(SOURCE / "program.f")],
                [str(fortad), "--mode", "forward", "--indep", "a", "--dep", "b,c", "--proc", "testiotbr", "--name", "jvp", "--module", "m", "--output", str(work / "forward.f90"), str(SOURCE / "program.f")],
                [str(fortad), "--mode", "reverse", "--indep", "a", "--dep", "b,c", "--proc", "testiotbr", "--name", "vjp", "--module", "m", "--output", str(work / "reverse.f90"), str(SOURCE / "program.f")],
            )
            for command in commands:
                completed = subprocess.run(command, capture_output=True, text=True)
                self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertIn("unsupported statement at line 7", completed.stdout + completed.stderr)
            for name in ("check.f90", "forward.f90", "reverse.f90"):
                self.assertFalse((work / name).exists())

if __name__ == "__main__":
    unittest.main()
