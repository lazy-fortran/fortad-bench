#!/usr/bin/env python3
"""Exactly three independent behavioral contracts for lh094."""
from __future__ import annotations
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

CASE = Path(__file__).resolve().parent; ROOT = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade")))
FORTAD = Path(os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad")); SOURCE = UPSTREAM / "nonRegressions" / "set01" / "lh094"
STRICT = ["-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto"]

class Lh094Contracts(unittest.TestCase):
    def test_independent_summary_oracle(self) -> None:
        completed = subprocess.run(["python3", str(CASE / "oracle.py"), str(SOURCE)], capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr); self.assertIn("oracle_status: pass", completed.stdout); self.assertIn("oracle_jvp:", completed.stdout); self.assertIn("oracle_vjp:", completed.stdout)

    def test_fresh_tapenade_generation_strict_compile(self) -> None:
        tapenade = UPSTREAM / "bin" / "tapenade"; self.assertTrue(tapenade.is_file())
        with tempfile.TemporaryDirectory(prefix="lh094-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, suffix in (("p", "p"), ("d", "d"), ("b", "b")):
                output = work / mode; output.mkdir(); command = [str(tapenade), f"-{mode}", "-ext", "nonRegressions/set01/lh094/MyGeneralLib"]
                if mode != "p": command += ["-root", "test"]
                command += ["-O", str(output), "-o", "lh094", str(SOURCE / "program.f")]
                generated = subprocess.run(command, cwd=UPSTREAM, capture_output=True, text=True); self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"lh094_{suffix}.f"; self.assertTrue(source.is_file()); compiled = subprocess.run(["gfortran", *STRICT, str(source)], capture_output=True, text=True); self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_fortad_check_pass_and_derivative_refusals(self) -> None:
        fortad = FORTAD / "build" / "fo" / "bin" / "fortad"; self.assertTrue(fortad.is_file())
        with tempfile.TemporaryDirectory(prefix="lh094-contract-fortad-") as temporary:
            work = Path(temporary); check = subprocess.run([str(fortad), "check", "--output", str(work / "check.f90"), str(SOURCE / "program.f")], capture_output=True, text=True); self.assertEqual(check.returncode, 0, check.stdout + check.stderr); self.assertTrue((work / "check.f90").is_file())
            for mode in ("forward", "reverse"):
                output = work / f"{mode}.f90"; completed = subprocess.run([str(fortad), "--mode", mode, "--indep", "a", "--dep", "b", "--proc", "test", "--name", f"lh094_{mode}", "--module", f"lh094_{mode}_mod", "--output", str(output), str(SOURCE / "program.f")], capture_output=True, text=True)
                self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr); self.assertIn("no derivative rule for 'DISACTIVATE'", completed.stdout + completed.stderr); self.assertFalse(output.exists())

if __name__ == "__main__":
    unittest.main()
