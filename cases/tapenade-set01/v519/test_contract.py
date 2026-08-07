#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v519 boundary."""

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
UPSTREAM = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
)
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")
)
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v519"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"
STRICT_FLAGS = [
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


def compile_source(source: Path, output: Path, module_dir: Path) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    return run(
        [
            os.environ.get("FC", "gfortran"),
            *STRICT_FLAGS,
            f"-I{SOURCE_DIR}",
            f"-J{module_dir}",
            "-c",
            str(source),
            "-o",
            str(output),
        ]
    )


class V519ContractTests(unittest.TestCase):
    def test_exact_and_stored_parser_reference_compile_strictly(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-standalone-program-no-procedure")
        self.assertEqual(manifest["stored_references"], ["program_p.f90", "program_p.msg"])
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a")
        self.assertEqual(run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(), manifest["upstream_revision"])
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v519-compile-") as directory:
            output = Path(directory)
            for name in ("program.f90", "program_p.f90"):
                completed = compile_source(
                    SOURCE_DIR / name, output / f"{name}.o", output / f"{name}-mod"
                )
                self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_fresh_tapenade_generation_and_applicable_strict_compile(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v519-tapenade-") as directory:
            output = Path(directory)
            for mode, flag, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        flag,
                        "-root",
                        "TEST_IT",
                        "-O",
                        ".",
                        "-o",
                        "v519",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=mode_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                self.assertTrue((mode_dir / f"v519_{suffix}.msg").is_file())
                if mode == "parser":
                    compiled = compile_source(
                        mode_dir / "v519_p.f90", output / "parser.o", output / "parser-mod"
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stderr)
                else:
                    self.assertFalse((mode_dir / f"v519_{suffix}.f90").exists())
                    self.assertIn("no active input nor output", generated.stdout)

    def test_exact_fortad_refusals_and_independent_semantic_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v519-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": [
                    "check",
                    "--proc",
                    "TEST_IT",
                    "--output",
                    str(output / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "X",
                    "--proc",
                    "TEST_IT",
                    "--name",
                    "v519_forward",
                    "--output",
                    str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "X",
                    "--dep",
                    "Y",
                    "--proc",
                    "TEST_IT",
                    "--name",
                    "v519_reverse",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertEqual(completed.returncode, 1, mode)
                self.assertIn("no procedure named 'TEST_IT' in this source", completed.stderr, mode)
                self.assertFalse((output / f"{mode}.f90").exists())

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_record_lengths: [117, 117, 120, 120]", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
