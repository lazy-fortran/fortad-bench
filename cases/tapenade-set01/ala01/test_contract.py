#!/usr/bin/env python3
"""Three behavioral contracts for the exact ala01 evidence package."""

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
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "ala01"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "gfortran")
STRICT = (
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fsyntax-only",
    "-fno-lto",
)
LEGACY = (
    "-std=legacy",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fsyntax-only",
    "-fno-lto",
)


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def compile_source(source: Path, flags: tuple[str, ...]) -> subprocess.CompletedProcess[str]:
    return run([FC, *flags, str(source)])


def fresh_tapenade(
    mode: str, flag: str, output: Path
) -> tuple[subprocess.CompletedProcess[str], Path, Path]:
    output.mkdir()
    completed = run(
        [
            str(TAPENADE),
            flag,
            "-context",
            "-root",
            "root",
            "-O",
            ".",
            "-o",
            "ala01",
            str(SOURCE_DIR / "program.f"),
        ],
        cwd=output,
    )
    suffix = {"parser": "p", "forward": "d", "reverse": "b"}[mode]
    return completed, output / f"ala01_{suffix}.f", output / f"ala01_{suffix}.msg"


class Ala01B01ContractTests(unittest.TestCase):
    def test_exact_source_and_stored_reference_strict_legacy_contract(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-fortad-unsupported-print-line-39",
        )
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["upstream_revision"],
        )
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

        exact = compile_source(SOURCE_DIR / "program.f", STRICT)
        tangent = compile_source(SOURCE_DIR / "program_d.f", STRICT)
        reverse = compile_source(SOURCE_DIR / "program_b.f", STRICT)
        self.assertEqual(exact.returncode, 0, exact.stderr)
        self.assertEqual(tangent.returncode, 0, tangent.stderr)
        self.assertNotEqual(reverse.returncode, 0)
        self.assertIn("Nonstandard type declaration REAL*8", reverse.stderr)
        for source in ("program.f", "program_d.f", "program_b.f"):
            legacy = compile_source(SOURCE_DIR / source, LEGACY)
            self.assertEqual(legacy.returncode, 0, f"{source}: {legacy.stderr}")

    def test_fresh_tapenade_generation_and_strict_legacy_contract(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-ala01-tapenade-") as temporary:
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
                return [
                    line
                    for line in path.read_text(encoding="utf-8").splitlines()
                    if not line.startswith("C  Tapenade ")
                ]

            self.assertEqual(
                without_banner(SOURCE_DIR / "program_d.f"),
                without_banner(generated["forward"]),
            )
            self.assertEqual(
                without_banner(SOURCE_DIR / "program_b.f"),
                without_banner(generated["reverse"]),
            )

    def test_exact_fortad_refusal_and_independent_semantic_oracle(self) -> None:
        commands = (
            ["check", "--proc", "root", "--output", "check.f90"],
            [
                "--mode",
                "forward",
                "--indep",
                "x,initial",
                "--dep",
                "y",
                "--proc",
                "root",
                "--name",
                "ala01_forward",
                "--module",
                "ala01_forward_mod",
                "--output",
                "forward.f90",
            ],
            [
                "--mode",
                "reverse",
                "--indep",
                "x,initial",
                "--dep",
                "y",
                "--proc",
                "root",
                "--name",
                "ala01_reverse",
                "--module",
                "ala01_reverse_mod",
                "--output",
                "reverse.f90",
            ],
        )
        with tempfile.TemporaryDirectory(prefix="fortad-ala01-fortad-") as temporary:
            work = Path(temporary)
            for arguments in commands:
                output = work / arguments[arguments.index("--output") + 1]
                completed = run(
                    [
                        "fo",
                        "exec",
                        "--no-build",
                        "fortad",
                        *arguments,
                        str(SOURCE_DIR / "program.f"),
                    ],
                    cwd=FORTAD_ROOT,
                )
                self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertIn(
                    "fortad: unsupported statement at line 39",
                    completed.stdout + completed.stderr,
                )
                self.assertFalse(output.exists(), output)

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_jvp_finite_difference: pass", oracle.stdout)
        self.assertIn("oracle_vjp_dot_product: pass", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
