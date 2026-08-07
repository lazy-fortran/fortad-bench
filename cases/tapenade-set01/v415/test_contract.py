#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v415 boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
DEFAULT_UPSTREAM = CASE.parents[2] / "upstream" / "tapenade"
if not DEFAULT_UPSTREAM.is_dir():
    DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
FORTAD_REPO = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v415"
FORTAD = FORTAD_REPO / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FLAGS = [
    "-std=f2018",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-cpp",
]


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class V415ContractTests(unittest.TestCase):
    def test_exact_upstream_strict_compile_and_stored_generation_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-invalid-stored-derivative-and-unsupported-allocatable",
        )
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        with tempfile.TemporaryDirectory(prefix="fortad-v415-exact-") as directory:
            output = Path(directory)
            (output / "mod").mkdir()
            primal = run(
                [
                    os.environ.get("FC", "gfortran"),
                    *FLAGS,
                    f"-I{SOURCE_DIR}",
                    f"-J{output / 'mod'}",
                    "-c",
                    str(SOURCE_DIR / "program.f90"),
                    "-o",
                    str(output / "program.o"),
                ]
            )
            self.assertEqual(primal.returncode, 0, primal.stdout + primal.stderr)
            stored = run(
                [
                    os.environ.get("FC", "gfortran"),
                    *FLAGS,
                    f"-I{SOURCE_DIR}",
                    f"-J{output / 'mod'}",
                    "-c",
                    str(SOURCE_DIR / "program_d.f90"),
                    "-o",
                    str(output / "program_d.o"),
                ]
            )
            self.assertNotEqual(stored.returncode, 0)
            self.assertIn("not an inquiry reference", stored.stderr)
            self.assertIn("Syntax error in expression", stored.stderr)
        self.assertIn("Unexpected operator: continue", (SOURCE_DIR / "program_d.msg").read_text())

    def test_fresh_tapenade_generation_and_strict_compile(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-v415-fresh-") as directory:
            output = Path(directory)
            for mode in ("p", "d", "b"):
                generated_dir = output / mode
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        f"-{mode}",
                        "-root",
                        "calc_force",
                        "-O",
                        ".",
                        "-o",
                        "v415",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = generated_dir / f"v415_{mode}.f90"
                self.assertTrue(source.is_file())
                compile_dir = output / f"mod-{mode}"
                compile_dir.mkdir()
                compiled = run(
                    [
                        os.environ.get("FC", "gfortran"),
                        *FLAGS,
                        f"-I{SOURCE_DIR}",
                        f"-J{compile_dir}",
                        "-c",
                        str(source),
                        "-o",
                        str(output / f"v415_{mode}.o"),
                    ]
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_exact_fortad_refusals_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v415-exact-") as directory:
            output = Path(directory)
            requests = (
                (
                    "parser",
                    [
                        "check",
                        "--proc",
                        "calc_force",
                        "--output",
                        str(output / "parser.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
                (
                    "forward",
                    [
                        "--mode",
                        "forward",
                        "--indep",
                        "geom,prop,obj,acc",
                        "--proc",
                        "calc_force",
                        "--name",
                        "v415_forward",
                        "--module",
                        "v415_forward_mod",
                        "--output",
                        str(output / "forward.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
                (
                    "reverse",
                    [
                        "--mode",
                        "reverse",
                        "--indep",
                        "geom,prop,acc",
                        "--dep",
                        "obj",
                        "--proc",
                        "calc_force",
                        "--name",
                        "v415_reverse",
                        "--module",
                        "v415_reverse_mod",
                        "--output",
                        str(output / "reverse.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
            )
            for mode, arguments in requests:
                completed = run([str(FORTAD), *arguments])
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn(
                    "unsupported allocation lifetime construct 'allocatable declaration/component'",
                    completed.stderr,
                    mode,
                )
                self.assertFalse((output / f"{mode}.f90").exists())
        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("finite_difference_max_error:", oracle.stdout)
        self.assertIn("adjoint_identity_residual:", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
