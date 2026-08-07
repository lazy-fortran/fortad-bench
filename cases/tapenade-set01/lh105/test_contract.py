#!/usr/bin/env python3
"""Exactly three independent behavioral contracts for the lh105 boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "lh105"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "gfortran")
STRICT_FIXED = (
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only",
    "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
)
LEGACY_FIXED = (
    "-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only",
    "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
)
STRICT_FREE = (
    "-std=f2018", "-ffree-form", "-ffree-line-length-none", "-fsyntax-only",
    "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
)
LEGACY_FREE = (
    "-std=legacy", "-ffree-form", "-ffree-line-length-none", "-fsyntax-only",
    "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
)


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def run_fortad(arguments: list[str], work: Path) -> subprocess.CompletedProcess[str]:
    return run(
        ["fo", "exec", "--no-build", "--cwd", str(work), "fortad", *arguments],
        cwd=FORTAD_ROOT,
    )


class Lh105ContractTests(unittest.TestCase):
    def test_independent_indexed_jvp_vjp_oracle(self) -> None:
        completed = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)])
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_source_inventory: pass", completed.stdout)
        self.assertIn("oracle_jvp_finite_difference: pass", completed.stdout)
        self.assertIn("oracle_vjp_adjoint_identity: pass", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_generation_and_both_compiler_gates(self) -> None:
        self.assertTrue(TAPENADE.is_file())
        with tempfile.TemporaryDirectory(prefix="fortad-lh105-tapenade-") as directory:
            work = Path(directory)
            for source_name in ("program.f", "program_b.f"):
                source = SOURCE_DIR / source_name
                for label, flags in (("strict", STRICT_FIXED), ("legacy", LEGACY_FIXED)):
                    compiled = run([FC, *flags, str(source)])
                    self.assertEqual(
                        compiled.returncode, 0,
                        f"{source_name} {label}: {compiled.stdout}\n{compiled.stderr}",
                    )
            for mode, flag, suffix, extra in (
                ("parser", "-p", "p", ()),
                ("forward", "-d", "d", ("-root", "top")),
                ("reverse", "-b", "b", ("-root", "top")),
            ):
                mode_dir = work / mode
                mode_dir.mkdir()
                generated = run(
                    [str(TAPENADE), flag, *extra, "-O", str(mode_dir), "-o", "lh105",
                     str(SOURCE_DIR / "program.f")],
                )
                self.assertEqual(
                    generated.returncode, 0,
                    f"{mode}: {generated.stdout}\n{generated.stderr}",
                )
                source = mode_dir / f"lh105_{suffix}.f"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((mode_dir / f"lh105_{suffix}.msg").is_file())
                for label, flags in (("strict", STRICT_FIXED), ("legacy", LEGACY_FIXED)):
                    compiled = run([FC, *flags, str(source)])
                    self.assertEqual(
                        compiled.returncode, 0,
                        f"{mode} {label}: {compiled.stdout}\n{compiled.stderr}",
                    )

    def test_exact_fortad_check_forward_and_reverse_boundary(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-lh105-fortad-") as directory:
            work = Path(directory)
            check_path = work / "check.f90"
            check = run_fortad(
                ["check", "--proc", "top", "--output", str(check_path),
                 str(SOURCE_DIR / "program.f")], work,
            )
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertTrue(check_path.is_file())
            forward_path = work / "forward.f90"
            forward = run_fortad(
                ["--mode", "forward", "--proc", "top", "--indep", "a,b",
                 "--name", "top_jvp", "--module", "top_jvp_mod", "--output",
                 str(forward_path), str(SOURCE_DIR / "program.f")], work,
            )
            self.assertEqual(forward.returncode, 0, forward.stdout + forward.stderr)
            self.assertTrue(forward_path.is_file())
            for source in (check_path, forward_path):
                for label, flags in (("strict", STRICT_FREE), ("legacy", LEGACY_FREE)):
                    compiled = run([FC, *flags, str(source)])
                    self.assertEqual(
                        compiled.returncode, 0,
                        f"{source.name} {label}: {compiled.stdout}\n{compiled.stderr}",
                    )

            reverse_path = work / "reverse.f90"
            reverse = run_fortad(
                ["--mode", "reverse", "--proc", "top", "--indep", "a,b", "--dep", "a",
                 "--name", "top_vjp", "--module", "top_vjp_mod", "--output",
                 str(reverse_path), str(SOURCE_DIR / "program.f")], work,
            )
            self.assertEqual(reverse.returncode, 0, reverse.stdout + reverse.stderr)
            self.assertTrue(reverse_path.is_file())
            for label, flags in (("strict", STRICT_FREE), ("legacy", LEGACY_FREE)):
                compiled = run([FC, *flags, str(reverse_path)])
                diagnostic = (compiled.stdout + compiled.stderr).lower()
                self.assertNotEqual(compiled.returncode, 0, f"{label}: {diagnostic}")
                self.assertIn("duplicate symbol", diagnostic)
                self.assertIn("a_b", diagnostic)


if __name__ == "__main__":
    unittest.main(verbosity=1)
