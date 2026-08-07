#!/usr/bin/env python3
"""Behavioral contracts for the bounded exact-source lh095 case."""
from __future__ import annotations
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

CASE = Path(__file__).resolve().parent
FORTAD = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"))
SOURCE = UPSTREAM / "nonRegressions" / "set01" / "lh095"
FIXED = ["-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface"]

def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True, check=False)

class Lh095ContractTests(unittest.TestCase):
    def test_independent_behavioral_oracle(self) -> None:
        completed = run("python3", str(CASE / "oracle.py"))
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_cases: 3", completed.stdout)
        self.assertIn("oracle_jvp_finite_difference: pass", completed.stdout)
        self.assertIn("oracle_vjp_adjoint_identity: pass", completed.stdout)

    def test_pinned_sources_and_fresh_tapenade_modes(self) -> None:
        tapenade = UPSTREAM / "bin" / "tapenade"
        self.assertTrue(tapenade.is_file())
        for name in ("program.f", "program_p.f", "program_d.f", "program_b.f", "program_dv.f"):
            self.assertTrue((SOURCE / name).is_file(), name)
        with tempfile.TemporaryDirectory(prefix="lh095-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, option, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                output = work / mode
                output.mkdir()
                command = [str(tapenade), option]
                if mode != "parser":
                    command += ["-root", "testliveness"]
                command += ["-O", str(output), "-o", "lh095", str(SOURCE / "program.f")]
                generated = run(*command)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                generated_source = output / f"lh095_{suffix}.f"
                self.assertTrue(generated_source.is_file())
                compiled = run("gfortran", *FIXED, "-fsyntax-only", str(generated_source))
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_compile_and_fortad_boundaries(self) -> None:
        stored_dv = run("gfortran", *FIXED, "-fsyntax-only", str(SOURCE / "program_dv.f"))
        self.assertNotEqual(stored_dv.returncode, 0)
        self.assertIn("DIFFSIZES.inc", stored_dv.stdout + stored_dv.stderr)
        fortad = FORTAD / "build" / "fo" / "bin" / "fortad"
        self.assertTrue(fortad.is_file())
        with tempfile.TemporaryDirectory(prefix="lh095-contract-fortad-") as temporary:
            work = Path(temporary)
            check = run(str(fortad), "check", "--proc", "testliveness", "--output", str(work / "check.f90"), str(SOURCE / "program.f"))
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            source_forward = run(str(fortad), "jvp", str(SOURCE / "program.f"), "a", "--proc", "testliveness", "--dep", "b", "--output", str(work / "source-forward.f90"))
            self.assertEqual(source_forward.returncode, 0, source_forward.stdout + source_forward.stderr)
            reverse_commands = (("source-reverse", ("vjp", str(SOURCE / "program.f"), "a", "--proc", "testliveness", "--dep", "b", "--output", str(work / "source-reverse.f90"))), ("compat-reverse", ("-b", "-root", "testliveness", "--dep", "b", "-O", str(work), "-o", "compat", str(SOURCE / "program.f"))))
            for label, command in reverse_commands:
                refused = run(str(fortad), *command)
                self.assertNotEqual(refused.returncode, 0, label)
                self.assertIn("assignment to undeclared 'sub1'", refused.stdout + refused.stderr)
            for option, suffix in (("-p", "p"), ("-d", "d")):
                output = work / f"compat_{suffix}"
                output.mkdir()
                compatible = run(str(fortad), option, "-root", "testliveness", "-O", str(output), "-o", "compat", str(SOURCE / "program.f"))
                self.assertEqual(compatible.returncode, 0, compatible.stdout + compatible.stderr)
                self.assertTrue((output / f"compat_{suffix}.f90").is_file())

if __name__ == "__main__":
    unittest.main()
