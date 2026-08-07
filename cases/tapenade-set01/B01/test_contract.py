#!/usr/bin/env python3
# Contract tests invoke the pinned tools and independent oracle directly.
"""Three behavioral contracts for exact B01 GRADFB evidence."""
from __future__ import annotations
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))).resolve()
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad"))).resolve()
SOURCE = UPSTREAM_ROOT / "nonRegressions" / "set01" / "B01" / "program.f"
TAPENADE = UPSTREAM_ROOT / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
FC = os.environ.get("FC", "gfortran")
FORTAD_PIN = "72ca2aa1c6c7d4b171b13a3e13c5190944080032"
STRICT = ("-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-I", str(SOURCE.parent))
LEGACY = ("-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-I", str(SOURCE.parent))


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class B01ContractTests(unittest.TestCase):
    def test_independent_determinant_jvp_vjp_oracle(self) -> None:
        completed = run(["python3", str(CASE / "oracle.py"), str(SOURCE.parent)])
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        for marker in ("oracle_source_inventory: exact GRADFB determinant body pass", "oracle_jvp_finite_difference: pass", "oracle_gradient_finite_difference: pass", "oracle_vjp_adjoint_identity: pass", "oracle_behavioral_cases: 3", "oracle_status: pass"):
            self.assertIn(marker, completed.stdout)

    def test_fresh_tapenade_generation_and_compiler_gates(self) -> None:
        self.assertTrue(TAPENADE.is_file())
        with tempfile.TemporaryDirectory(prefix="fortad-B01-tapenade-") as directory:
            work = Path(directory)
            for mode, flag, suffix, root in (("parser", "-p", "p", None), ("forward", "-d", "d", "gradfb"), ("reverse", "-b", "b", "gradfb")):
                mode_dir = work / mode
                mode_dir.mkdir()
                command = [str(TAPENADE), flag]
                if root is not None:
                    command += ["-root", root]
                command += ["-O", ".", "-o", "b01", str(SOURCE)]
                generated = run(command, cwd=mode_dir)
                self.assertEqual(generated.returncode, 0, f"{mode}: {generated.stdout}\n{generated.stderr}")
                source = mode_dir / f"b01_{suffix}.f"
                self.assertTrue(source.is_file() and source.stat().st_size > 0)
                self.assertTrue((mode_dir / f"b01_{suffix}.msg").is_file())
                legacy = run([FC, *LEGACY, str(source)])
                self.assertEqual(legacy.returncode, 0, f"{mode}: {legacy.stderr}")
                strict = run([FC, *STRICT, str(source)])
                self.assertNotEqual(strict.returncode, 0, mode)
                self.assertIn("REAL*8", strict.stdout + strict.stderr)

    def test_exact_fortad_parser_jvp_vjp_refusal(self) -> None:
        self.assertTrue(FORTAD.is_file())
        pinned = run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"])
        self.assertEqual(pinned.returncode, 0, pinned.stderr)
        self.assertEqual(pinned.stdout.strip(), FORTAD_PIN)
        with tempfile.TemporaryDirectory(prefix="fortad-B01-exact-") as directory:
            work = Path(directory)
            commands = (
                ("check", [str(FORTAD), "check", "--proc", "gradfb", "--output", str(work / "check.f90"), str(SOURCE)]),
                ("jvp", [str(FORTAD), "jvp", "x,y,z", "--proc", "gradfb", "--name", "b01_jvp", "--module", "b01_jvp_mod", "--output", str(work / "jvp.f90"), str(SOURCE)]),
                ("vjp", [str(FORTAD), "vjp", "x,y,z", "--dep", "vol6", "--proc", "gradfb", "--name", "b01_vjp", "--module", "b01_vjp_mod", "--output", str(work / "vjp.f90"), str(SOURCE)]),
            )
            for mode, command in commands:
                completed = run(command)
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn("could not locate the end of this do construct", completed.stdout + completed.stderr)
                self.assertFalse((work / f"{mode}.f90").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
