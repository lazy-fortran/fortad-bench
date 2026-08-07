#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the lh084 boundary."""

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
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "lh084"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
STRICT = ("-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only")
LEGACY = ("-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only")


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class Lh084ContractTests(unittest.TestCase):
    def test_exact_and_stored_fixed_form_compiler_behavior(self) -> None:
        strict_logs = []
        for name in ("program.f", "program_b.f"):
            strict = run([os.environ.get("FC", "gfortran"), *STRICT, str(SOURCE_DIR / name)])
            self.assertNotEqual(strict.returncode, 0, name)
            self.assertIn("GNU Extension: Nonstandard type declaration REAL*8", strict.stderr, name)
            strict_logs.append(strict.stderr)
            legacy = run([os.environ.get("FC", "gfortran"), *LEGACY, str(SOURCE_DIR / name)])
            self.assertEqual(legacy.returncode, 0, f"{name}: {legacy.stderr}")
        self.assertEqual(len(strict_logs), 2)

    def test_fresh_tapenade_generation_and_stored_reverse_behavior(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-lh084-tapenade-") as directory:
            output = Path(directory)
            for mode, flag, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run([str(TAPENADE), flag, "-O", ".", "-o", "lh084", str(SOURCE_DIR / "program.f")], cwd=mode_dir)
                self.assertEqual(generated.returncode, 0, f"{mode}: {generated.stdout}\n{generated.stderr}")
                source = mode_dir / f"lh084_{suffix}.f"
                message = mode_dir / f"lh084_{suffix}.msg"
                self.assertTrue(source.is_file(), source)
                self.assertTrue(message.is_file(), message)
                compiled = run([os.environ.get("FC", "gfortran"), *LEGACY, str(source)])
                self.assertEqual(compiled.returncode, 0, f"{mode}: {compiled.stderr}")
            fresh = (output / "reverse" / "lh084_b.f").read_text(encoding="utf-8").splitlines()
            stored = (SOURCE_DIR / "program_b.f").read_text(encoding="utf-8").splitlines()
            normalized = lambda lines: [line for line in lines if not line.startswith("C  Tapenade ")]
            self.assertEqual(normalized(fresh), normalized(stored))
            self.assertEqual(
                hashlib.sha256((output / "reverse" / "lh084_b.msg").read_bytes()).hexdigest(),
                hashlib.sha256((SOURCE_DIR / "program_b.msg").read_bytes()).hexdigest(),
            )

    def test_fortad_exact_refusal_and_independent_numerical_oracle(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-lh084-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": ["check", "--output", str(output / "parser.f")],
                "forward": ["--mode", "forward", "--indep", "t", "--name", "lh084_d", "--module", "lh084_d_mod", "--output", str(output / "forward.f")],
                "reverse": ["--mode", "reverse", "--indep", "t", "--dep", "t", "--name", "lh084_b", "--module", "lh084_b_mod", "--output", str(output / "reverse.f")],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f")])
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn("could not locate the end of this do construct", completed.stderr, mode)
                self.assertFalse((output / f"{mode}.f").exists(), mode)
        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_status: pass", oracle.stdout)
        self.assertIn("adjoint_identity_residual:", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
