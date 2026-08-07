#!/usr/bin/env python3
"""Exactly three behavioral contracts for the ala03 evidence package."""

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
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))).resolve()
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad"))).resolve()
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "ala03"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
FC = os.environ.get("FC", "mpifort")
MPI_INCLUDE = Path(os.environ.get("MPI_INCLUDE", "/usr/include"))
SUPPORT_INCLUDE = UPSTREAM / "ADFirstAidKit"
sys.path.insert(0, str(CASE))
import oracle  # noqa: E402


STRICT = (
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors",
    "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-fno-lto",
    f"-I{MPI_INCLUDE}", f"-I{SUPPORT_INCLUDE}",
)
LEGACY = (
    "-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra",
    "-Wimplicit-interface", "-fsyntax-only", "-fno-lto",
    f"-I{MPI_INCLUDE}", f"-I{SUPPORT_INCLUDE}",
)


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def compile_source(source: Path, flags: tuple[str, ...]) -> subprocess.CompletedProcess[str]:
    return run([FC, *flags, str(source)])


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fresh_tapenade(mode: str, output: Path) -> tuple[subprocess.CompletedProcess[str], Path, Path]:
    output.mkdir()
    flag, suffix = {"parser": ("-p", "p"), "forward": ("-d", "d"), "reverse": ("-b", "b")}[mode]
    completed = run([
        str(TAPENADE), flag, "-noisize", "-head", "wave_resolution(u_global)/(c)",
        "-I", str(SUPPORT_INCLUDE), "-I", str(MPI_INCLUDE), "-O", ".", "-o", "ala03",
        str(SOURCE_DIR / "program.f"),
    ], cwd=output)
    return completed, output / f"ala03_{suffix}.f", output / f"ala03_{suffix}.msg"


class Ala03ContractTests(unittest.TestCase):
    def test_exact_source_and_stored_reference_compiler_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-fortad-external-mpi-update-rules")
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "72ca2aa1c6c7d4b171b13a3e13c5190944080032")
        self.assertEqual(run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(), manifest["upstream_revision"])
        for relative, expected in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(sha256(source), expected, relative)

        oracle.source_inventory(SOURCE_DIR / "program.f")
        exact_strict = compile_source(SOURCE_DIR / "program.f", STRICT)
        self.assertNotEqual(exact_strict.returncode, 0)
        self.assertIn("Type mismatch between actual argument", exact_strict.stderr)
        self.assertEqual(compile_source(SOURCE_DIR / "program.f", LEGACY).returncode, 0)
        self.assertEqual(compile_source(SOURCE_DIR / "program_d.f", STRICT).returncode, 0)
        stored_reverse = compile_source(SOURCE_DIR / "program_b.f", STRICT)
        self.assertNotEqual(stored_reverse.returncode, 0)
        self.assertIn("Nonstandard type declaration INTEGER*4", stored_reverse.stderr)
        self.assertEqual(compile_source(SOURCE_DIR / "program_b.f", LEGACY).returncode, 0)

    def test_fresh_tapenade_generation_and_independent_wave_jvp(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-ala03-tapenade-") as directory:
            output = Path(directory)
            generated: dict[str, tuple[Path, Path]] = {}
            for mode in ("parser", "forward", "reverse"):
                completed, source, message = fresh_tapenade(mode, output / mode)
                self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertTrue(source.is_file())
                self.assertTrue(message.is_file())
                generated[mode] = (source, message)

            parser_strict = compile_source(generated["parser"][0], STRICT)
            self.assertNotEqual(parser_strict.returncode, 0)
            self.assertIn("Type mismatch between actual argument", parser_strict.stderr)
            self.assertEqual(compile_source(generated["parser"][0], LEGACY).returncode, 0)
            self.assertEqual(compile_source(generated["forward"][0], STRICT).returncode, 0)
            self.assertEqual(compile_source(generated["forward"][0], LEGACY).returncode, 0)
            reverse_strict = compile_source(generated["reverse"][0], STRICT)
            self.assertNotEqual(reverse_strict.returncode, 0)
            self.assertIn("Nonstandard type declaration INTEGER*4", reverse_strict.stderr)
            self.assertEqual(compile_source(generated["reverse"][0], LEGACY).returncode, 0)

        c, dc, n_global, nsteps = 0.73, -0.41, 9, 5
        analytic = oracle.wave_jvp(c, dc, n_global, nsteps)
        h = 1.0e-6
        plus = oracle.wave_primal(c + h * dc, n_global, nsteps)
        minus = oracle.wave_primal(c - h * dc, n_global, nsteps)
        self.assertLess(
            max(abs(a - (b - d) / (2.0 * h)) for a, b, d in zip(analytic, plus, minus)),
            2.0e-9,
        )

    def test_fortad_refusal_and_independent_wave_vjp(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-ala03-fortad-") as directory:
            output = Path(directory)
            check = run([
                str(FORTAD), "check", "--proc", "wave_resolution", "--output",
                str(output / "check.f90"), str(SOURCE_DIR / "program.f"),
            ])
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertTrue((output / "check.f90").is_file())
            forward = run([
                str(FORTAD), "--mode", "forward", "--proc", "wave_resolution", "--indep", "c",
                "--dep", "u_global", "--name", "ala03_d", "--module", "ala03_d_mod",
                "--output", str(output / "forward.f90"), str(SOURCE_DIR / "program.f"),
            ])
            reverse = run([
                str(FORTAD), "--mode", "reverse", "--proc", "wave_resolution", "--indep", "c",
                "--dep", "u_global", "--name", "ala03_b", "--module", "ala03_b_mod",
                "--output", str(output / "reverse.f90"), str(SOURCE_DIR / "program.f"),
            ])
            self.assertNotEqual(forward.returncode, 0)
            self.assertIn("no derivative rule for the call to 'update'", forward.stderr)
            self.assertFalse((output / "forward.f90").exists())
            self.assertNotEqual(reverse.returncode, 0)
            self.assertIn("no reverse rule for the call to 'update'", reverse.stderr)
            self.assertFalse((output / "reverse.f90").exists())

        c, dc, n_global, nsteps = 0.73, -0.41, 9, 5
        seed = [oracle.math.sin(0.3 * (i + 1)) for i in range(n_global)]
        tangent = oracle.wave_jvp(c, dc, n_global, nsteps)
        lhs = sum(a * b for a, b in zip(seed, tangent))
        rhs = oracle.wave_vjp(c, seed, n_global, nsteps) * dc
        self.assertAlmostEqual(lhs, rhs, delta=2.0e-11)

        report = (CASE / "result.txt").read_text(encoding="utf-8")
        if "runner_result: blocked" in report:
            markers = (
                "runner_result: blocked",
                "blocker: pinned FortAD checkout mismatch before case probes",
            )
        else:
            markers = (
                "tapenade_generation: parser=0 forward=0 reverse=0",
                "fortad_exact_behavior: check=0 output=pass forward=1 reverse=1",
            )
        for marker in (*markers, "oracle_status: pass", "no_repaired_port: true"):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main(verbosity=2)
