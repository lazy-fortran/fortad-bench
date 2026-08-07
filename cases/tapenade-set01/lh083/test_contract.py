#!/usr/bin/env python3
"""Exactly three independent behavioral tests for the lh083 case."""

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
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
).resolve()
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh083"
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")
).resolve()
TAPENADE = UPSTREAM_ROOT / "bin" / "tapenade"
MANIFEST = CASE / "manifest.toml"
SOURCE = UPSTREAM / "program.f"


def compile_fixed(source: Path, output: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            os.environ.get("FC", "gfortran"),
            "-std=f2018",
            "-ffixed-form",
            "-ffixed-line-length-none",
            "-pedantic-errors",
            "-Wall",
            "-Wextra",
            "-Wimplicit-interface",
            "-fsyntax-only",
            "-J",
            str(output),
            str(source),
        ],
        capture_output=True,
        text=True,
        check=False,
    )


def compile_free(source: Path, output: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            os.environ.get("FC", "gfortran"),
            "-std=f2018",
            "-ffree-form",
            "-ffree-line-length-none",
            "-pedantic-errors",
            "-Wall",
            "-Wextra",
            "-Wimplicit-interface",
            "-fsyntax-only",
            str(source),
        ],
        capture_output=True,
        text=True,
        check=False,
    )


class Lh083ContractTests(unittest.TestCase):
    def test_exact_source_and_stored_reference_compile_and_preserve_semantics(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "7adc75030db3fa4422339d82d2725ae29ee13dac")
        self.assertEqual(
            hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            "fdde8e7dcc0350a2323509420b7413882c206b7ed833c1c45f1ef93d8adc370a",
        )
        with tempfile.TemporaryDirectory(prefix="lh083-contract-compile-") as temp:
            module_dir = Path(temp)
            for source in (SOURCE, UPSTREAM / "program_b.f"):
                completed = compile_fixed(source, module_dir)
                self.assertEqual(completed.returncode, 0, completed.stderr)
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn("call modify(j)", source)
        self.assertIn("n = 2*n+1", source)

    def test_fresh_pinned_tapenade_generation_and_strict_compilation(self) -> None:
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        with tempfile.TemporaryDirectory(prefix="lh083-contract-tapenade-") as temp:
            root = Path(temp)
            outputs = {
                "parser": ("-p",),
                "forward": ("-d", "-root", "aa"),
                "reverse": ("-b", "-root", "aa"),
            }
            for label, args in outputs.items():
                directory = root / label
                directory.mkdir()
                completed = subprocess.run(
                    [str(TAPENADE), *args, "-O", ".", "-o", "lh083", str(SOURCE)],
                    cwd=directory,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(completed.returncode, 0, completed.stderr)
            for generated in (
                root / "parser" / "lh083_p.f",
                root / "forward" / "lh083_d.f",
                root / "reverse" / "lh083_b.f",
            ):
                self.assertTrue(generated.is_file() and generated.stat().st_size > 0)
                completed = compile_fixed(generated, root / "mod")
                self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_independent_trace_oracle_and_fortad_exact_boundary(self) -> None:
        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(UPSTREAM)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_first_out_of_bounds_iteration: 5", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)

        fortad = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
        self.assertTrue(fortad.is_file(), "run fo build before the contract")
        with tempfile.TemporaryDirectory(prefix="lh083-contract-fortad-") as temp:
            output = Path(temp) / "derivative.f90"
            check = subprocess.run(
                [str(fortad), "check", "--proc", "aa", "--output", str(output), str(SOURCE)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(check.returncode, 0, check.stderr)
            self.assertTrue(output.is_file())
            self.assertEqual(compile_free(output, Path(temp)).returncode, 0)
            output.unlink()

            jvp = subprocess.run(
                [str(fortad), "jvp", "X,Y", "--proc", "aa", "--name", "lh083_jvp",
                 "--output", str(output), str(SOURCE)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(jvp.returncode, 0, jvp.stderr)
            self.assertTrue(output.is_file())
            self.assertEqual(compile_free(output, Path(temp)).returncode, 0)
            output.unlink()

            vjp = subprocess.run(
                [str(fortad), "vjp", "X,Y", "--dep", "X", "--proc", "aa", "--name", "lh083_vjp",
                 "--output", str(output), str(SOURCE)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(vjp.returncode, 1, vjp.stderr)
            self.assertEqual(
                vjp.stderr.strip(),
                "fortad: reverse mode: 'X' is both read and written in the same loop; that needs per-iteration storage",
            )
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
