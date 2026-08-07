#!/usr/bin/env python3
"""Exactly three independent contracts for the lh090 boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh090"
STRICT = [
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only",
    "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
]


class Lh090ContractTests(unittest.TestCase):
    def test_independent_finite_prefix_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(SOURCE)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_control_flow: positive-input branch repeats", completed.stdout)
        self.assertIn("oracle_tangent: finite-prefix recurrence agrees", completed.stdout)
        self.assertIn("oracle_reverse: finite-prefix reverse dot-product identity", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_artifacts_strict_compile(self) -> None:
        tapenade = UPSTREAM_ROOT / "bin" / "tapenade"
        self.assertTrue(tapenade.is_file())
        with tempfile.TemporaryDirectory(prefix="lh090-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, directory, stem in (
                ("p", "parser", "lh090_p"),
                ("d", "forward", "lh090_d"),
                ("b", "reverse", "lh090_b"),
            ):
                output = work / directory
                output.mkdir()
                command = [str(tapenade), f"-{mode}"]
                if mode != "p":
                    command += ["-root", "testInitAdj"]
                command += ["-O", str(output), "-o", "lh090", str(SOURCE / "program.f")]
                generated = subprocess.run(command, capture_output=True, text=True, check=False)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"{stem}.f"
                self.assertTrue(source.is_file())
                compiled = subprocess.run(
                    ["gfortran", *STRICT, "-c", str(source), "-o", str(work / f"{stem}.o")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_fortad_exact_three_mode_refusal(self) -> None:
        fortad = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
        self.assertTrue(fortad.is_file())
        with tempfile.TemporaryDirectory(prefix="lh090-contract-fortad-") as temporary:
            work = Path(temporary)
            commands = (
                [str(fortad), "check", "--output", str(work / "check.f90"), str(SOURCE / "program.f")],
                [str(fortad), "--mode", "forward", "--indep", "x", "--dep", "y", "--proc", "testInitAdj",
                 "--name", "lh090_jvp", "--module", "lh090_jvp_mod", "--output", str(work / "forward.f90"),
                 str(SOURCE / "program.f")],
                [str(fortad), "--mode", "reverse", "--indep", "x", "--dep", "y", "--proc", "testInitAdj",
                 "--name", "lh090_vjp", "--module", "lh090_vjp_mod", "--output", str(work / "reverse.f90"),
                 str(SOURCE / "program.f")],
            )
            for command in commands:
                completed = subprocess.run(command, capture_output=True, text=True, check=False)
                self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertIn("unsupported statement at line 11", completed.stdout + completed.stderr)
            self.assertFalse((work / "check.f90").exists())
            self.assertFalse((work / "forward.f90").exists())
            self.assertFalse((work / "reverse.f90").exists())


if __name__ == "__main__":
    unittest.main()
