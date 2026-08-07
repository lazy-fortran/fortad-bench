#!/usr/bin/env python3
"""Exactly three behavioral contracts for the lh109 evidence package."""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "lh109"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "gfortran")
STRICT = ("-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-fno-lto")
LEGACY = ("-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-fno-lto")


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class Lh109ContractTests(unittest.TestCase):
    def test_independent_bounded_behavioral_oracle(self) -> None:
        completed = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)])
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_source_inventory: pass", completed.stdout)
        self.assertIn("oracle_bounded_primal: pass", completed.stdout)
        self.assertIn("oracle_jvp_finite_difference: pass", completed.stdout)
        self.assertIn("oracle_vjp_dot_product: pass", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_generation_and_strict_legacy_gates(self) -> None:
        self.assertTrue(TAPENADE.is_file())
        with tempfile.TemporaryDirectory(prefix="fortad-lh109-tapenade-") as temporary:
            work = Path(temporary)
            for mode, flag, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                output = work / mode
                output.mkdir()
                generated = run([str(TAPENADE), flag, "-root", "adj3", "-O", ".", "-o", "lh109", str(SOURCE_DIR / "program.f")], cwd=output)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"lh109_{suffix}.f"
                message = output / f"lh109_{suffix}.msg"
                self.assertTrue(source.is_file(), source)
                self.assertTrue(message.is_file(), message)
                strict = run([FC, *STRICT, str(source)])
                legacy = run([FC, *LEGACY, str(source)])
                self.assertEqual(strict.returncode, 0, f"{mode} strict: {strict.stderr}")
                self.assertEqual(legacy.returncode, 0, f"{mode} legacy: {legacy.stderr}")
            fresh = [line for line in (work / "reverse" / "lh109_b.f").read_text().splitlines() if not line.startswith("C  Tapenade ")]
            stored = [line for line in (SOURCE_DIR / "program_b.f").read_text().splitlines() if not line.startswith("C  Tapenade ")]
            self.assertEqual(fresh, stored)
            def normalized_message(path: Path) -> list[str]:
                lines = path.read_text().splitlines()
                return [re.sub(r"^[0-9]+ ", "", line) for line in lines
                        if "Command: Took subroutine adj3 as default differentiation root" not in line]

            self.assertEqual(normalized_message(work / "reverse" / "lh109_b.msg"), normalized_message(SOURCE_DIR / "program_b.msg"))

    def test_exact_fortad_three_mode_refusal(self) -> None:
        self.assertTrue(FORTAD.is_file())
        with tempfile.TemporaryDirectory(prefix="fortad-lh109-fortad-") as temporary:
            work = Path(temporary)
            commands = (
                [str(FORTAD), "check", "--proc", "adj3", "--output", str(work / "check.f90"), str(SOURCE_DIR / "program.f")],
                [str(FORTAD), "--mode", "forward", "--proc", "adj3", "--indep", "z,t", "--dep", "z,t", "--name", "adj3_d", "--module", "adj3_d_mod", "--output", str(work / "forward.f90"), str(SOURCE_DIR / "program.f")],
                [str(FORTAD), "--mode", "reverse", "--proc", "adj3", "--indep", "z,t", "--dep", "z,t", "--name", "adj3_b", "--module", "adj3_b_mod", "--output", str(work / "reverse.f90"), str(SOURCE_DIR / "program.f")],
            )
            for command in commands:
                completed = run(command)
                self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertIn("unsupported statement at line 6", completed.stdout + completed.stderr)
            for name in ("check.f90", "forward.f90", "reverse.f90"):
                self.assertFalse((work / name).exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
