#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v427 boundary."""

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
        "TAPENADE_REPO", "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"
    )
)
FORTAD_REPO = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v427"
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class V427ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_references_compile(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-allocatable-module-state-and-no-active-derivative")
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a")
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["upstream_revision"],
        )
        for relative, expected in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(UPSTREAM / relative), expected, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v427-exact-") as directory:
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

    def test_fresh_tapenade_generation_and_strict_compile_where_applicable(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v427-fresh-") as directory:
            output = Path(directory)
            parser_dir = output / "parser"
            parser_dir.mkdir()
            parser = run(
                [
                    str(TAPENADE),
                    "-association",
                    "byaddress",
                    "-p",
                    "-root",
                    "setupData",
                    "-O",
                    ".",
                    "-o",
                    "v427",
                    str(SOURCE_DIR / "program.f90"),
                ],
                cwd=parser_dir,
            )
            self.assertEqual(parser.returncode, 0, parser.stdout + parser.stderr)
            parser_source = parser_dir / "v427_p.f90"
            self.assertTrue(parser_source.is_file())
            self.assertTrue((parser_dir / "v427_p.msg").is_file())
            parser_compile = compile_source(
                parser_source, output / "parser.o", output / "parser-mod"
            )
            self.assertEqual(parser_compile.returncode, 0, parser_compile.stdout + parser_compile.stderr)

            for mode, suffix in (("forward", "d"), ("reverse", "b")):
                generated_dir = output / mode
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        "-association",
                        "byaddress",
                        f"-{suffix}",
                        "-root",
                        "setupData",
                        "-O",
                        ".",
                        "-o",
                        "v427",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                self.assertTrue((generated_dir / f"v427_{suffix}.msg").is_file())
                self.assertIn("AD06", (generated_dir / f"v427_{suffix}.msg").read_text())
                self.assertFalse((generated_dir / f"v427_{suffix}.f90").exists())

    def test_exact_fortad_refusals_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v427-exact-") as directory:
            output = Path(directory)
            requests = {
                "parser": [
                    str(FORTAD),
                    "check",
                    "--proc",
                    "setupData",
                    "--output",
                    str(output / "parser.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
                "forward": [
                    str(FORTAD),
                    "--mode",
                    "forward",
                    "--proc",
                    "setupData",
                    "--indep",
                    "dim",
                    "--name",
                    "v427_forward",
                    "--module",
                    "v427_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
                "reverse": [
                    str(FORTAD),
                    "--mode",
                    "reverse",
                    "--proc",
                    "setupData",
                    "--indep",
                    "dim",
                    "--dep",
                    "someTData",
                    "--name",
                    "v427_reverse",
                    "--module",
                    "v427_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
            }
            for mode, command in requests.items():
                completed = run(command)
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn(
                    "unsupported allocation lifetime construct 'allocatable declaration/component' at line 2",
                    completed.stderr,
                )
                self.assertFalse((output / f"{mode}.f90").exists())

        oracle = run(["python3", str(CASE / "oracle.py")], cwd=CASE)
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("second_call_effect: someTData=5 then allocation_failure=i_already_allocated", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
