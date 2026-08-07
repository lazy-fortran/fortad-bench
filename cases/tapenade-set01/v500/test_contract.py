#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v500 boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = Path(
    os.environ.get(
        "TAPENADE_REPO",
        "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade",
    )
)
FORTAD_REPO = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v500"
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


def compile_source(
    source: Path, output: Path, module_dir: Path
) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True)
    return run(
        [
            os.environ.get("FC", "gfortran"),
            *FLAGS,
            f"-I{SOURCE_DIR}",
            f"-J{module_dir}",
            "-c",
            str(source),
            "-o",
            str(output),
        ]
    )


class V500ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_references_strict_compile(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-unsupported-data-and-singular-output",
        )
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        for relative, expected in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), expected)

        with tempfile.TemporaryDirectory(prefix="fortad-v500-exact-") as directory:
            output = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", output / "program.o", output / "primal-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_b.f90",
                output / "program_b.o",
                output / "stored-mod",
            )
        self.assertEqual(primal.returncode, 0, primal.stdout + primal.stderr)
        self.assertEqual(stored.returncode, 0, stored.stdout + stored.stderr)
        self.assertIn("Unused variable", primal.stderr)
        self.assertIn("implicit interface", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compile_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v500-fresh-") as directory:
            output = Path(directory)
            for mode, suffix in (("p", "parser"), ("d", "tangent"), ("b", "reverse")):
                generated_dir = output / suffix
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        "-association",
                        "byaddress",
                        f"-{mode}",
                        "-root",
                        "nl_model_mie_orig",
                        "-O",
                        ".",
                        "-o",
                        "v500",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = generated_dir / f"v500_{mode}.f90"
                self.assertTrue(source.is_file())
                self.assertTrue((generated_dir / f"v500_{mode}.msg").is_file())
                compiled = compile_source(
                    source, output / f"v500_{mode}.o", output / f"mod-{suffix}"
                )
                if mode in ("p", "d"):
                    self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                else:
                    self.assertNotEqual(compiled.returncode, 0)
                    self.assertIn("INTEGER*4", compiled.stderr)

    def test_exact_fortad_refusal_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v500-fortad-") as directory:
            output = Path(directory)
            commands = (
                [
                    "check",
                    "--proc",
                    "nl_model_mie_orig",
                    "--output",
                    str(output / "parser.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
                [
                    "--mode",
                    "forward",
                    "--indep",
                    "alpha_ext",
                    "--proc",
                    "nl_model_mie_orig",
                    "--name",
                    "v500_forward",
                    "--module",
                    "v500_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
                [
                    "--mode",
                    "reverse",
                    "--indep",
                    "alpha_ext",
                    "--dep",
                    "alpha_ext",
                    "--proc",
                    "nl_model_mie_orig",
                    "--name",
                    "v500_reverse",
                    "--module",
                    "v500_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
            )
            for command in commands:
                completed = run([str(FORTAD), *command])
                self.assertNotEqual(completed.returncode, 0, completed.stdout)
                self.assertIn("unsupported statement at line 21", completed.stderr)
            self.assertFalse((output / "parser.f90").exists())
            self.assertFalse((output / "forward.f90").exists())
            self.assertFalse((output / "reverse.f90").exists())

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_status: pass singular-pp-normalization", oracle.stdout)
        self.assertIn("pp_normalization: singular-zero-over-zero", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
