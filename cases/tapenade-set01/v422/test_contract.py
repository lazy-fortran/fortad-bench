#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v422 boundary."""

from __future__ import annotations

import hashlib
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
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v422"
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def compile_source(source: Path, output: Path, module_dir: Path) -> subprocess.CompletedProcess[str]:
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


class V422ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_references_compile(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-undefined-function-result-and-codegen",
        )
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        for relative, expected in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(sha256(source), expected, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v422-exact-") as directory:
            output = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", output / "program.o", output / "primal-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_Rd.f90",
                output / "program_Rd.o",
                output / "stored-mod",
            )
        self.assertEqual(primal.returncode, 0, primal.stdout + primal.stderr)
        self.assertEqual(stored.returncode, 0, stored.stdout + stored.stderr)
        self.assertIn("Return value of function", primal.stderr)
        self.assertIn("Return value of function", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compile(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v422-fresh-") as directory:
            output = Path(directory)
            for mode, suffix in (("p", "parser"), ("d", "forward"), ("b", "reverse")):
                generated_dir = output / suffix
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        "-association",
                        "byaddress",
                        f"-{mode}",
                        "-root",
                        "f4",
                        "-O",
                        ".",
                        "-o",
                        "v422",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = generated_dir / f"v422_{mode}.f90"
                self.assertTrue(source.is_file())
                self.assertTrue((generated_dir / f"v422_{mode}.msg").is_file())
                compiled = compile_source(
                    source, output / f"v422_{mode}.o", output / f"mod-{suffix}"
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                self.assertIn("Return value", compiled.stderr)

    def test_exact_fortad_boundaries_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v422-fortad-") as directory:
            output = Path(directory)
            parser = run(
                [
                    str(FORTAD),
                    "check",
                    "--proc",
                    "f4",
                    "--output",
                    str(output / "parser.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ]
            )
            self.assertEqual(parser.returncode, 0, parser.stdout + parser.stderr)
            self.assertTrue((output / "parser.f90").is_file())
            parser_compile = compile_source(
                output / "parser.f90", output / "parser.o", output / "parser-mod"
            )
            self.assertNotEqual(parser_compile.returncode, 0)
            self.assertIn("Invalid character in name", parser_compile.stderr)

            forward = run(
                [
                    str(FORTAD),
                    "--mode",
                    "forward",
                    "--proc",
                    "f4",
                    "--indep",
                    "t",
                    "--name",
                    "v422_forward",
                    "--module",
                    "v422_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ]
            )
            self.assertEqual(forward.returncode, 0, forward.stdout + forward.stderr)
            self.assertTrue((output / "forward.f90").is_file())
            forward_compile = compile_source(
                output / "forward.f90", output / "forward.o", output / "forward-mod"
            )
            self.assertNotEqual(forward_compile.returncode, 0)
            self.assertIn("Invalid character in name", forward_compile.stderr)

            reverse = run(
                [
                    str(FORTAD),
                    "--mode",
                    "reverse",
                    "--proc",
                    "f4",
                    "--indep",
                    "t",
                    "--dep",
                    "t",
                    "--name",
                    "v422_reverse",
                    "--module",
                    "v422_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ]
            )
            self.assertEqual(reverse.returncode, 0, reverse.stdout + reverse.stderr)
            self.assertTrue((output / "reverse.f90").is_file())
            reverse_compile = compile_source(
                output / "reverse.f90", output / "reverse.o", output / "reverse-mod"
            )
            self.assertNotEqual(reverse_compile.returncode, 0)
            self.assertIn("Duplicate symbol", reverse_compile.stderr)

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("mutation=3.90625", oracle.stdout)
        self.assertIn("function_result=undefined", oracle.stdout)
        self.assertIn("adjoint_identity_residual=0.000e+00", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
