#!/usr/bin/env python3
"""Exactly three behavioral contracts for the ht02 evidence package."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
).resolve()
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad"))
).resolve()
SOURCE_DIR = UPSTREAM_ROOT / "nonRegressions" / "set01" / "ht02"
TAPENADE = UPSTREAM_ROOT / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
FC = os.environ.get("FC", "gfortran")
FORTAD_PIN = "93f41d60d882778699ec1a887ce9a665a75afcf8"
STRICT = (
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fsyntax-only",
)
LEGACY = (
    "-std=legacy",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fsyntax-only",
)


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class Ht02ContractTests(unittest.TestCase):
    def test_independent_fixed_read_behavioral_oracle(self) -> None:
        completed = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)])
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_source_inventory: exact external-read shape pass", completed.stdout)
        self.assertIn("oracle_jvp_finite_difference: pass", completed.stdout)
        self.assertIn("oracle_vjp_adjoint_identity: pass", completed.stdout)
        self.assertIn("oracle_behavioral_cases: 3", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_generation_and_strict_legacy_compilation(self) -> None:
        self.assertTrue(TAPENADE.is_file())
        with tempfile.TemporaryDirectory(prefix="fortad-ht02-tapenade-") as directory:
            work = Path(directory)
            exact_sources = (SOURCE_DIR / "program.f", SOURCE_DIR / "program_b.f")
            for source in exact_sources:
                for flags in (STRICT, LEGACY):
                    compiled = run([FC, *flags, str(source)])
                    self.assertEqual(compiled.returncode, 0, compiled.stderr)

            for mode, flag, suffix, root in (
                ("parser", "-p", "p", None),
                ("forward", "-d", "d", "top"),
                ("reverse", "-b", "b", "top"),
            ):
                mode_dir = work / mode
                mode_dir.mkdir()
                command = [str(TAPENADE), flag]
                if root is not None:
                    command += ["-root", root]
                command += ["-O", ".", "-o", "ht02", str(SOURCE_DIR / "program.f")]
                generated = run(command, cwd=mode_dir)
                self.assertEqual(
                    generated.returncode,
                    0,
                    f"{mode}: {generated.stdout}\n{generated.stderr}",
                )
                source = mode_dir / f"ht02_{suffix}.f"
                self.assertTrue(source.is_file() and source.stat().st_size > 0)
                self.assertTrue((mode_dir / f"ht02_{suffix}.msg").is_file())
                for flags in (STRICT, LEGACY):
                    compiled = run([FC, *flags, str(source)])
                    self.assertEqual(compiled.returncode, 0, compiled.stderr)

    def test_exact_fortad_check_forward_reverse_refuse_external_read(self) -> None:
        self.assertTrue(FORTAD.is_file())
        pinned = run(
            ["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]
        )
        self.assertEqual(pinned.returncode, 0, pinned.stderr)
        self.assertEqual(pinned.stdout.strip(), FORTAD_PIN)
        with tempfile.TemporaryDirectory(prefix="fortad-ht02-fortad-") as directory:
            work = Path(directory)
            commands = (
                (
                    "check",
                    [
                        str(FORTAD),
                        "check",
                        "--proc",
                        "top",
                        "--output",
                        str(work / "check.f90"),
                        str(SOURCE_DIR / "program.f"),
                    ],
                ),
                (
                    "forward",
                    [
                        str(FORTAD),
                        "jvp",
                        "a",
                        "--proc",
                        "top",
                        "--name",
                        "ht02_jvp",
                        "--module",
                        "ht02_jvp_mod",
                        "--output",
                        str(work / "forward.f90"),
                        str(SOURCE_DIR / "program.f"),
                    ],
                ),
                (
                    "reverse",
                    [
                        str(FORTAD),
                        "vjp",
                        "a",
                        "--dep",
                        "a",
                        "--proc",
                        "top",
                        "--name",
                        "ht02_vjp",
                        "--module",
                        "ht02_vjp_mod",
                        "--output",
                        str(work / "reverse.f90"),
                        str(SOURCE_DIR / "program.f"),
                    ],
                ),
            )
            for mode, command in commands:
                completed = run(command)
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn("unsupported statement at line 7", completed.stdout + completed.stderr)
                self.assertFalse((work / f"{mode}.f90").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
