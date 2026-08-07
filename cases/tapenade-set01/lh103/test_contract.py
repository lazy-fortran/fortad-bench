#!/usr/bin/env python3
"""Exactly three behavioral contracts for the lh103 evidence package."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "lh103"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "gfortran")
STRICT = ("-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only")
LEGACY = ("-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only")


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class Lh103ContractTests(unittest.TestCase):
    def test_independent_finite_semantic_oracle(self) -> None:
        completed = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)])
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_jvp_finite_difference: pass", completed.stdout)
        self.assertIn("oracle_vjp_dot_product: pass", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_generation_and_strict_compilation(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-lh103-tapenade-") as directory:
            output = Path(directory)
            for mode, flag, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run([str(TAPENADE), flag, "-O", ".", "-o", "lh103", str(SOURCE_DIR / "program.f")], cwd=mode_dir)
                self.assertEqual(generated.returncode, 0, f"{mode}: {generated.stdout}\n{generated.stderr}")
                source = mode_dir / f"lh103_{suffix}.f"
                message = mode_dir / f"lh103_{suffix}.msg"
                self.assertTrue(source.is_file(), source)
                self.assertTrue(message.is_file(), message)
                compiled = run([FC, *STRICT, str(source)])
                self.assertEqual(compiled.returncode, 0, f"{mode}: {compiled.stderr}")
            fresh = [line for line in (output / "reverse" / "lh103_b.f").read_text().splitlines() if not line.startswith("C  Tapenade ")]
            stored = [line for line in (SOURCE_DIR / "program_b.f").read_text().splitlines() if not line.startswith("C  Tapenade ")]
            self.assertEqual(fresh, stored)
            self.assertEqual(hashlib.sha256((output / "reverse" / "lh103_b.msg").read_bytes()).hexdigest(), hashlib.sha256((SOURCE_DIR / "program_b.msg").read_bytes()).hexdigest())

    def test_exact_fortad_check_jvp_vjp_boundary(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-lh103-fortad-") as directory:
            output = Path(directory)
            check = run([str(FORTAD), "check", "--proc", "h", "--output", str(output / "check.f"), str(SOURCE_DIR / "program.f")])
            self.assertEqual(check.returncode, 0, check.stderr)
            fortad_strict = ("-std=f2018", "-ffree-form", "-ffree-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only")
            self.assertEqual(run([FC, *fortad_strict, str(output / "check.f")]).returncode, 0)
            forward = run([str(FORTAD), "--mode", "forward", "--indep", "A,B,C,r", "--name", "h_d", "--module", "h_d_mod", "--output", str(output / "forward.f"), str(SOURCE_DIR / "program.f")])
            self.assertEqual(forward.returncode, 0, forward.stderr)
            self.assertEqual(run([FC, *fortad_strict, str(output / "forward.f")]).returncode, 0)
            reverse = run([str(FORTAD), "--mode", "reverse", "--indep", "A,B,C,r", "--dep", "r", "--name", "h_b", "--module", "h_b_mod", "--output", str(output / "reverse.f"), str(SOURCE_DIR / "program.f")])
            self.assertNotEqual(reverse.returncode, 0)
            self.assertIn("per-iteration storage", reverse.stderr)
            self.assertFalse((output / "reverse.f").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
