#!/usr/bin/env python3
"""Exactly three independent behavioral contracts for the lh078 boundary."""

from __future__ import annotations

import os
import subprocess
import tarfile
import tempfile
import unittest
from io import BytesIO
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "lh078"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD_COMMIT = "7adc75030db3fa4422339d82d2725ae29ee13dac"
FIXED_FLAGS = (
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only",
    "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
)
FREE_FLAGS = (
    "-std=f2018", "-ffree-form", "-ffree-line-length-none", "-fsyntax-only",
    "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
)


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def compile_source(source: Path, flags: tuple[str, ...]) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="fortad-lh078-compile-") as directory:
        return run([
            os.environ.get("FC", "gfortran"), *flags, str(source),
            "-o", str(Path(directory) / "x.o"),
        ])


def pinned_fortad(out: Path) -> Path:
    """Build the requested FortAD revision without changing its worktree."""
    current = subprocess.check_output(
        ["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"], text=True
    ).strip()
    if current == FORTAD_COMMIT:
        candidate = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
        if candidate.is_file():
            return candidate
    source = out / ("fortad-" + FORTAD_COMMIT)
    source.mkdir()
    archive = subprocess.check_output(
        ["git", "-C", str(FORTAD_ROOT), "archive", FORTAD_COMMIT]
    )
    with tarfile.open(fileobj=BytesIO(archive), mode="r:") as stream:
        stream.extractall(source)
    (out / "fortfront").symlink_to(FORTAD_ROOT.parent / "fortfront")
    (out / "fortgen").symlink_to(FORTAD_ROOT.parent / "fortgen")
    built = run(["fo", "build"], cwd=source)
    if built.returncode:
        raise AssertionError(built.stdout + built.stderr)
    candidate = source / "build" / "fo" / "bin" / "fortad"
    if not candidate.is_file():
        raise AssertionError("pinned FortAD build did not produce fortad")
    return candidate


class Lh078Contracts(unittest.TestCase):
    def test_exact_source_and_stored_references_reject_strictly(self) -> None:
        """The exact source and all stored Fortran products hit compiler boundaries."""
        exact = compile_source(SOURCE_DIR / "program.f", FIXED_FLAGS)
        self.assertNotEqual(exact.returncode, 0)
        self.assertIn("Syntax error in SUBROUTINE statement", exact.stderr)
        self.assertIn("REAL*8", exact.stderr)
        for name in ("program_p.f", "program_d.f", "program_b.f"):
            compiled = compile_source(SOURCE_DIR / name, FIXED_FLAGS)
            self.assertNotEqual(compiled.returncode, 0, name)
            self.assertIn("REAL*8", compiled.stderr, name)
        multidirectional = compile_source(SOURCE_DIR / "program_dv.f", FIXED_FLAGS)
        self.assertNotEqual(multidirectional.returncode, 0)
        self.assertIn("Cannot open included file", multidirectional.stderr)

    def test_fresh_pinned_tapenade_products_hit_the_same_boundary(self) -> None:
        """Fresh Tapenade products are generated, then independently compiled strictly."""
        with tempfile.TemporaryDirectory(prefix="fortad-lh078-tapenade-") as directory:
            root = Path(directory)
            modes = (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
                ("vector", "-d", "dv"),
            )
            for mode, option, suffix in modes:
                output = root / mode
                output.mkdir()
                command = [str(TAPENADE), option]
                if mode != "parser":
                    command += ["-root", "testPower"]
                if mode == "vector":
                    command += ["-multi"]
                command += ["-O", str(output), "-o", "lh078", str(SOURCE_DIR / "program.f")]
                generated = run(command)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"lh078_{suffix}.f"
                message = output / f"lh078_{suffix}.msg"
                self.assertTrue(source.is_file())
                self.assertTrue(message.is_file())
                self.assertIn("(DF03) variable c[3] is used before initialized", message.read_text())
                strict = compile_source(source, FIXED_FLAGS)
                self.assertNotEqual(strict.returncode, 0, mode)
            vector_error = compile_source(root / "vector" / "lh078_dv.f", FIXED_FLAGS)
            self.assertIn("Cannot open included file", vector_error.stderr)

    def test_fortad_exact_behavior_matches_independent_oracle(self) -> None:
        """The independent source inventory agrees with exact FortAD boundaries."""
        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("adjoint_identity: pass", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)
        with tempfile.TemporaryDirectory(prefix="fortad-lh078-fortad-") as directory:
            output = Path(directory)
            fortad = pinned_fortad(output)
            check = run([
                str(fortad), "check", "--output", str(output / "check.f90"),
                str(SOURCE_DIR / "program.f"),
            ])
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertTrue((output / "check.f90").is_file())
            self.assertNotEqual(compile_source(output / "check.f90", FREE_FLAGS).returncode, 0)
            forward = run([
                str(fortad), "--mode", "forward", "--indep", "x", "--dep", "r",
                "--proc", "testPower", "--output", str(output / "forward.f90"),
                str(SOURCE_DIR / "program.f"),
            ])
            self.assertEqual(forward.returncode, 0, forward.stdout + forward.stderr)
            self.assertTrue((output / "forward.f90").is_file())
            self.assertNotEqual(compile_source(output / "forward.f90", FREE_FLAGS).returncode, 0)
            reverse = run([
                str(fortad), "--mode", "reverse", "--indep", "x", "--dep", "r",
                "--proc", "testPower", "--output", str(output / "reverse.f90"),
                str(SOURCE_DIR / "program.f"),
            ])
            self.assertNotEqual(reverse.returncode, 0)
            self.assertIn("assignment to undeclared 'r8(4)'", reverse.stdout + reverse.stderr)
            self.assertFalse((output / "reverse.f90").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
