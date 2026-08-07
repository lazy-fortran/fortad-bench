#!/usr/bin/env python3
"""Exactly three behavioral contracts for the lh107 evidence package."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "lh107"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "gfortran")
STRICT_FIXED = ("-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only")
LEGACY_FIXED = ("-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only")
STRICT_FREE = ("-std=f2018", "-ffree-form", "-ffree-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only")


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class Lh107ContractTests(unittest.TestCase):
    def test_independent_behavioral_oracle(self) -> None:
        completed = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)])
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_source_inventory: pass", completed.stdout)
        self.assertIn("oracle_jvp_finite_difference: pass", completed.stdout)
        self.assertIn("oracle_vjp_adjoint_identity: pass", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_exact_stored_and_fresh_tapenade_compiler_gates(self) -> None:
        self.assertTrue(TAPENADE.is_file())
        with tempfile.TemporaryDirectory(prefix="fortad-lh107-tapenade-") as directory:
            output = Path(directory)

            exact = run([FC, *STRICT_FIXED, str(SOURCE_DIR / "program.f")])
            self.assertEqual(exact.returncode, 0, exact.stdout + exact.stderr)
            exact_legacy = run([FC, *LEGACY_FIXED, str(SOURCE_DIR / "program.f")])
            self.assertEqual(exact_legacy.returncode, 0, exact_legacy.stdout + exact_legacy.stderr)
            stored_strict = run([FC, *STRICT_FIXED, str(SOURCE_DIR / "program_b.f")])
            self.assertNotEqual(stored_strict.returncode, 0)
            stored_legacy = run([FC, *LEGACY_FIXED, str(SOURCE_DIR / "program_b.f")])
            self.assertEqual(stored_legacy.returncode, 0, stored_legacy.stdout + stored_legacy.stderr)

            expected = {
                "parser": ("-p", "p", True, True),
                "forward": ("-d", "d", False, False),
                "reverse": ("-b", "b", False, True),
            }
            for mode, (flag, suffix, strict_pass, legacy_pass) in expected.items():
                mode_dir = output / mode
                mode_dir.mkdir()
                command = [str(TAPENADE), flag]
                if mode != "parser":
                    command += ["-root", "test"]
                command += ["-O", str(mode_dir), "-o", "lh107", str(SOURCE_DIR / "program.f")]
                generated = run(command)
                self.assertEqual(generated.returncode, 0, f"{mode}: {generated.stdout}\n{generated.stderr}")
                source = mode_dir / f"lh107_{suffix}.f"
                message = mode_dir / f"lh107_{suffix}.msg"
                self.assertTrue(source.is_file())
                self.assertTrue(message.is_file())
                strict = run([FC, *STRICT_FIXED, str(source)])
                legacy = run([FC, *LEGACY_FIXED, str(source)])
                self.assertEqual(strict.returncode == 0, strict_pass, f"{mode}: {strict.stderr}")
                self.assertEqual(legacy.returncode == 0, legacy_pass, f"{mode}: {legacy.stderr}")

    def test_exact_fortad_tapenade_cli_products_strict_compile(self) -> None:
        self.assertTrue(FORTAD.is_file())
        with tempfile.TemporaryDirectory(prefix="fortad-lh107-cli-") as directory:
            output = Path(directory)
            check = run([str(FORTAD), "check", "--proc", "test", "--output", str(output / "check.f90"), str(SOURCE_DIR / "program.f")])
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            check_compile = run([FC, *STRICT_FREE, str(output / "check.f90")])
            self.assertEqual(check_compile.returncode, 0, check_compile.stdout + check_compile.stderr)

            for mode, flag, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run([str(FORTAD), flag, "-root", "test", "-O", str(mode_dir), "-o", "lh107", str(SOURCE_DIR / "program.f")])
                self.assertEqual(generated.returncode, 0, f"{mode}: {generated.stdout}\n{generated.stderr}")
                source = mode_dir / f"lh107_{suffix}.f90"
                self.assertTrue(source.is_file())
                compiled = run([FC, *STRICT_FREE, str(source)])
                self.assertEqual(compiled.returncode, 0, f"{mode}: {compiled.stdout}\n{compiled.stderr}")


if __name__ == "__main__":
    unittest.main(verbosity=1)
