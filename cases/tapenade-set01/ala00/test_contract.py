#!/usr/bin/env python3
"""Exactly three behavioral contracts for the ala00 evidence package."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))).resolve()
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")).resolve()
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "ala00"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
FC = os.environ.get("FC", "gfortran")
STRICT = [
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors",
    "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto", "-fsyntax-only",
]
LEGACY = [
    "-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra",
    "-Wimplicit-interface", "-fno-lto", "-fsyntax-only",
]


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class Ala00B01ContractTests(unittest.TestCase):
    def test_exact_source_and_stored_references_have_independent_compiler_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-fortad-unsupported-print-and-reverse-real8")
        self.assertEqual(run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(), manifest["upstream_revision"])
        self.assertEqual(run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]).stdout.strip(), manifest["fortad_revision"])
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-ala00-exact-") as temporary:
            work = Path(temporary)
            for name in ("program.f", "program_p.f", "program_d.f"):
                for label, flags in (("strict", STRICT), ("legacy", LEGACY)):
                    completed = run([FC, *flags, str(SOURCE_DIR / name), "-o", str(work / f"{name}-{label}.o")])
                    self.assertEqual(completed.returncode, 0, f"{name} {label}: {completed.stderr}")
            strict_reverse = run([FC, *STRICT, str(SOURCE_DIR / "program_b.f"), "-o", str(work / "reverse-strict.o")])
            self.assertNotEqual(strict_reverse.returncode, 0)
            self.assertIn("REAL*8", strict_reverse.stderr)
            legacy_reverse = run([FC, *LEGACY, str(SOURCE_DIR / "program_b.f"), "-o", str(work / "reverse-legacy.o")])
            self.assertEqual(legacy_reverse.returncode, 0, legacy_reverse.stderr)

    def test_fresh_pinned_tapenade_generation_and_strict_legacy_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-ala00-tapenade-") as temporary:
            work = Path(temporary)
            for mode, flag, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                output = work / mode
                output.mkdir()
                generated = run(
                    [str(TAPENADE), flag, "-root", "root", "-O", str(output), "-o", "ala00", str(SOURCE_DIR / "program.f")],
                    cwd=UPSTREAM,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"ala00_{suffix}.f"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((output / f"ala00_{suffix}.msg").is_file())
                strict = run([FC, *STRICT, str(source), "-o", str(work / f"{mode}-strict.o")])
                legacy = run([FC, *LEGACY, str(source), "-o", str(work / f"{mode}-legacy.o")])
                if mode == "reverse":
                    self.assertNotEqual(strict.returncode, 0, strict.stderr)
                    self.assertIn("REAL*8", strict.stderr)
                else:
                    self.assertEqual(strict.returncode, 0, strict.stderr)
                self.assertEqual(legacy.returncode, 0, f"{mode}: {legacy.stderr}")

    def test_fortad_three_mode_refusal_and_independent_fixed_point_oracle(self) -> None:
        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        for marker in (
            "oracle_source_shape: exact root fixed-point and print inventory pass",
            "oracle_primal: finite fixed-point map pass",
            "oracle_jvp: hand finite-iteration JVP agrees with central difference",
            "oracle_vjp: hand reverse recurrence passes dot-product identity",
            "oracle_status: pass",
        ):
            self.assertIn(marker, oracle.stdout)

        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-ala00-fortad-") as temporary:
            work = Path(temporary)
            requests = {
                "check": ["check", "--proc", "root", "--output", str(work / "check.f90")],
                "forward": ["--mode", "forward", "--proc", "root", "--indep", "x,initial", "--dep", "y", "--name", "ala00_d", "--module", "ala00_d_mod", "--output", str(work / "forward.f90")],
                "reverse": ["--mode", "reverse", "--proc", "root", "--indep", "x,initial", "--dep", "y", "--name", "ala00_b", "--module", "ala00_b_mod", "--output", str(work / "reverse.f90")],
            }
            for mode, arguments in requests.items():
                refused = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f")])
                self.assertNotEqual(refused.returncode, 0, mode)
                self.assertIn("unsupported statement at line 39", refused.stdout + refused.stderr, mode)
                self.assertFalse((work / f"{mode}.f90").exists(), mode)


if __name__ == "__main__":
    unittest.main(verbosity=1)
