#!/usr/bin/env python3
"""Exactly three behavioral contracts for the pinned ala04 boundary."""

from __future__ import annotations

import hashlib
import math
import os
import re
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from oracle import root_jvp, root_map, root_vjp, source_inventory  # noqa: E402


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))).resolve()
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")).resolve()
SOURCE_DIR = UPSTREAM_ROOT / "nonRegressions" / "set01" / "ala04"
SOURCE = SOURCE_DIR / "program.f"
TAPENADE = UPSTREAM_ROOT / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
FC = os.environ.get("FC", "gfortran")
STRICT = [
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors",
    "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto", "-fsyntax-only",
]
LEGACY = [
    "-std=legacy", "-ffixed-form", "-ffixed-line-length-none",
    "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto", "-fsyntax-only",
]


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def without_tapenade_banner(path: Path) -> str:
    return "".join(line for line in path.read_text(encoding="latin-1").splitlines(keepends=True)
                    if not line.startswith("C  Tapenade "))


def without_message_number(path: Path) -> str:
    return re.sub(r"^[0-9]+\s*", "", path.read_text(encoding="latin-1"), flags=re.MULTILINE)


class Ala04ContractTests(unittest.TestCase):
    def test_exact_source_hashes_legacy_runtime_and_independent_primal_oracle(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-fortad-real8-declaration-boundary")
        self.assertEqual(run(["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD"]).stdout.strip(), manifest["upstream_revision"])
        self.assertEqual(run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]).stdout.strip(), manifest["fortad_revision"])
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM_ROOT / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest, relative)

        source_inventory(SOURCE)
        value, outer_iterations, inner_iterations = root_map(1.0)
        self.assertTrue(math.isclose(value, 0.9999999999490585, abs_tol=2.0e-15))
        self.assertEqual((outer_iterations, inner_iterations), (133, 10158))
        for name in ("program.f", "program_p.f", "program_d.f", "program_b.f"):
            strict = run([FC, *STRICT, str(SOURCE_DIR / name)])
            self.assertNotEqual(strict.returncode, 0, name)
            self.assertIn("REAL*8", strict.stderr, name)
            legacy = run([FC, *LEGACY, str(SOURCE_DIR / name)])
            self.assertEqual(legacy.returncode, 0, f"{name}: {legacy.stderr}")

        with tempfile.TemporaryDirectory(prefix="fortad-ala04-primal-") as directory:
            executable = Path(directory) / "primal"
            built = run([
                FC, "-std=legacy", "-ffixed-form", "-ffixed-line-length-none",
                "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
                str(SOURCE), "-o", str(executable),
            ])
            self.assertEqual(built.returncode, 0, built.stderr)
            primal = run([str(executable)])
            self.assertEqual(primal.returncode, 0, primal.stderr)
            numbers = [float(token) for token in re.findall(r"[-+]?\d+\.\d+(?:[EeDd][-+]?\d+)?", primal.stdout)]
            self.assertTrue(any(math.isclose(number, value, rel_tol=0.0, abs_tol=2.0e-14) for number in numbers), primal.stdout)

    def test_fresh_pinned_tapenade_three_mode_generation_and_compiler_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-ala04-tapenade-") as directory:
            work = Path(directory)
            for mode, flag, suffix, stored in (
                ("parser", "-p", "p", "program_p"),
                ("forward", "-d", "d", "program_d"),
                ("reverse", "-b", "b", "program_b"),
            ):
                mode_dir = work / mode
                mode_dir.mkdir()
                generated = run(
                    [str(TAPENADE), flag, "-context", "-O", ".", "-o", "ala04", str(SOURCE)],
                    cwd=mode_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                fresh = mode_dir / f"ala04_{suffix}.f"
                self.assertTrue(fresh.is_file() and fresh.stat().st_size > 0, fresh)
                self.assertTrue((mode_dir / f"ala04_{suffix}.msg").is_file())
                self.assertEqual(without_tapenade_banner(fresh), without_tapenade_banner(SOURCE_DIR / f"{stored}.f"))
                self.assertEqual(without_message_number(mode_dir / f"ala04_{suffix}.msg"), without_message_number(SOURCE_DIR / f"{stored}.msg"))
                strict = run([FC, *STRICT, str(fresh)])
                self.assertNotEqual(strict.returncode, 0, mode)
                self.assertIn("REAL*8", strict.stderr, mode)
                legacy = run([FC, *LEGACY, str(fresh)])
                self.assertEqual(legacy.returncode, 0, f"{mode}: {legacy.stderr}")

    def test_fortad_parser_boundary_refusals_and_independent_jvp_vjp_oracle(self) -> None:
        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE)])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        for marker in (
            "oracle_source_shape: exact nested FP2/TOTO recurrence inventory pass",
            "oracle_primal:",
            "oracle_jvp: hand nested-recurrence JVP agrees with central difference",
            "oracle_vjp: hand reverse recurrence passes dot-product identity",
            "oracle_status: pass",
        ):
            self.assertIn(marker, oracle.stdout)
        tangent, _ = root_jvp(1.0, 24.0, 0.37, -0.23)
        bar_x, bar_initial_z = root_vjp(1.0, 24.0, 0.83)
        self.assertTrue(math.isclose(0.83 * tangent, bar_x * 0.37 + bar_initial_z * -0.23, abs_tol=2.0e-12))

        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-ala04-fortad-") as directory:
            work = Path(directory)
            check = run([
                str(FORTAD), "check", "--proc", "FP2", "--output", str(work / "check.f90"), str(SOURCE),
            ])
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            checked = work / "check.f90"
            self.assertTrue(checked.is_file())
            checked_text = checked.read_text(encoding="utf-8")
            self.assertIn("subroutine FP2(x, y)", checked_text)
            self.assertIn("y = z * x", checked_text)
            self.assertNotIn("REAL*8", checked_text)
            self.assertNotIn("DO WHILE", checked_text)

            forward = run([
                str(FORTAD), "--mode", "forward", "--proc", "FP2", "--indep", "x", "--dep", "y",
                "--name", "ala04_d", "--module", "ala04_d_mod", "--output", str(work / "forward.f90"), str(SOURCE),
            ])
            self.assertNotEqual(forward.returncode, 0)
            self.assertIn("independent 'x' is not declared in FP2", forward.stdout + forward.stderr)
            self.assertFalse((work / "forward.f90").exists())

            reverse = run([
                str(FORTAD), "--mode", "reverse", "--proc", "FP2", "--indep", "x", "--dep", "y",
                "--name", "ala04_b", "--module", "ala04_b_mod", "--output", str(work / "reverse.f90"), str(SOURCE),
            ])
            self.assertNotEqual(reverse.returncode, 0)
            self.assertIn("dependent 'y' is not declared in FP2", reverse.stdout + reverse.stderr)
            self.assertFalse((work / "reverse.f90").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
