#!/usr/bin/env python3
"""Exactly three behavioral contracts for the pinned ala05 evidence package."""

from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "ala05"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "gfortran")
STRICT = ("-std=f2018", "-ffree-form", "-ffree-line-length-none", "-pedantic-errors",
          "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-fno-lto")
LEGACY = ("-std=legacy", "-ffree-form", "-ffree-line-length-none", "-Wall",
          "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-fno-lto")

sys.path.insert(0, str(CASE))
import oracle  # noqa: E402


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def compile_source(source: Path, flags: tuple[str, ...]) -> subprocess.CompletedProcess[str]:
    return run([FC, *flags, str(source)])


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fresh_tapenade(mode: str, flag: str, output: Path) -> tuple[subprocess.CompletedProcess[str], Path, Path]:
    output.mkdir()
    completed = run([
        str(TAPENADE), flag, "-head", "NFP(y)/(x)", "-context", "-fixinterface",
        "-O", ".", "-o", "ala05", str(SOURCE_DIR / "program.f90")
    ], cwd=output)
    suffix = {"parser": "p", "forward": "d", "reverse": "b"}[mode]
    return completed, output / f"ala05_{suffix}.f90", output / f"ala05_{suffix}.msg"


class Ala05ContractTests(unittest.TestCase):
    def test_exact_source_and_stored_reference_boundary_plus_primal_oracle(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "72ca2aa1c6c7d4b171b13a3e13c5190944080032")
        self.assertEqual(run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
                         manifest["upstream_revision"])
        for relative, expected in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(UPSTREAM / relative), expected, relative)
        oracle.source_inventory(SOURCE_DIR / "program.f90")

        exact = compile_source(SOURCE_DIR / "program.f90", STRICT)
        parser = compile_source(SOURCE_DIR / "program_p.f90", STRICT)
        tangent = compile_source(SOURCE_DIR / "program_d.f90", STRICT)
        reverse = compile_source(SOURCE_DIR / "program_b.f90", STRICT)
        self.assertEqual(exact.returncode, 0, exact.stderr)
        self.assertEqual(parser.returncode, 0, parser.stderr)
        self.assertEqual(tangent.returncode, 0, tangent.stderr)
        self.assertNotEqual(reverse.returncode, 0)
        self.assertIn("Nonstandard type declaration REAL*8", reverse.stderr)
        for name in ("program.f90", "program_p.f90", "program_d.f90", "program_b.f90"):
            completed = compile_source(SOURCE_DIR / name, LEGACY)
            self.assertEqual(completed.returncode, 0, f"{name}: {completed.stderr}")

        value, final_x, _, counts = oracle.nfp_value(5.0)
        self.assertEqual((len(counts), sum(counts)), (50, 457))
        self.assertAlmostEqual(final_x, 5.999999977648258, places=14)
        self.assertAlmostEqual(value, 2.346524320087252, places=14)

    def test_fresh_pinned_tapenade_three_mode_generation_and_oracle_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-ala05-tapenade-") as temporary:
            work = Path(temporary)
            generated: dict[str, Path] = {}
            for mode, flag in (("parser", "-p"), ("forward", "-d"), ("reverse", "-b")):
                completed, source, message = fresh_tapenade(mode, flag, work / mode)
                self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertTrue(source.is_file(), source)
                self.assertTrue(message.is_file(), message)
                generated[mode] = source
                strict = compile_source(source, STRICT)
                legacy = compile_source(source, LEGACY)
                if mode == "reverse":
                    self.assertNotEqual(strict.returncode, 0)
                    self.assertIn("Nonstandard type declaration REAL*8", strict.stderr)
                else:
                    self.assertEqual(strict.returncode, 0, f"{mode}: {strict.stderr}")
                self.assertEqual(legacy.returncode, 0, f"{mode}: {legacy.stderr}")

            def without_banner(path: Path) -> list[str]:
                return [line for line in path.read_text().splitlines()
                        if not line.startswith("!  Tapenade ")]

            self.assertEqual(without_banner(SOURCE_DIR / "program_p.f90"),
                             without_banner(generated["parser"]))
            self.assertEqual(without_banner(SOURCE_DIR / "program_d.f90"),
                             without_banner(generated["forward"]))
            reverse_text = generated["reverse"].read_text()
            self.assertIn("ADSTACK_STARTREPEAT", reverse_text)
            self.assertIn("ADSTACK_ENDREPEAT", reverse_text)
            self.assertIn("zbconv", (SOURCE_DIR / "program_b.f90").read_text())

        analytic, counts = oracle.nfp_jvp(5.0, 0.37)
        h = 1.0e-6
        finite_difference = (oracle.nfp_value(5.0 + h * 0.37)[0] -
                             oracle.nfp_value(5.0 - h * 0.37)[0]) / (2.0 * h)
        self.assertEqual(sum(counts), 457)
        self.assertAlmostEqual(analytic, finite_difference, delta=2.0e-8)

    def test_exact_fortad_three_mode_refusal_plus_independent_vjp_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        self.assertEqual(
            run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]).stdout.strip(),
            "72ca2aa1c6c7d4b171b13a3e13c5190944080032",
        )
        requests = {
            "check": [str(FORTAD), "check", "--proc", "NFP", "--output", "check.f90",
                      str(SOURCE_DIR / "program.f90")],
            "forward": [str(FORTAD), "--mode", "forward", "--proc", "NFP", "--indep", "x",
                        "--dep", "y", "--name", "ala05_d", "--module", "ala05_d_mod",
                        "--output", "forward.f90", str(SOURCE_DIR / "program.f90")],
            "reverse": [str(FORTAD), "--mode", "reverse", "--proc", "NFP", "--indep", "x",
                        "--dep", "y", "--name", "ala05_b", "--module", "ala05_b_mod",
                        "--output", "reverse.f90", str(SOURCE_DIR / "program.f90")],
        }
        with tempfile.TemporaryDirectory(prefix="fortad-ala05-fortad-") as temporary:
            work = Path(temporary)
            for mode, command in requests.items():
                output_name = command[command.index("--output") + 1]
                command[command.index("--output") + 1] = str(work / output_name)
                completed = run(command)
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn("fortad: parse failed: ERROR at line 27, column 16: Unrecognized statement: DO WHILE (",
                                  completed.stdout + completed.stderr)
                self.assertFalse((work / output_name).exists())

        analytic, _ = oracle.nfp_jvp(5.0, 0.37)
        gradient = oracle.nfp_vjp(5.0, 0.83)
        self.assertAlmostEqual(0.83 * analytic, gradient * 0.37, delta=2.0e-12)
        oracle_result = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")])
        self.assertEqual(oracle_result.returncode, 0, oracle_result.stdout + oracle_result.stderr)
        self.assertIn("oracle_status: pass", oracle_result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
