#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v419 boundary."""

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
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v419"
FORTAD = FORTAD_REPO / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "gfortran")
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
    module_dir.mkdir(parents=True, exist_ok=True)
    return run(
        [
            FC,
            *FLAGS,
            f"-I{SOURCE_DIR}",
            f"-I{UPSTREAM / 'nonRegressions'}",
            f"-J{module_dir}",
            "-c",
            str(source),
            "-o",
            str(output),
        ]
    )


class V419ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_reference_compile_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-invalid-upstream-and-unsupported-allocatable-context",
        )
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a")
        self.assertEqual(len(manifest["contract_tests"]), 3)
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        source_text = (SOURCE_DIR / "program.f90").read_text(encoding="utf-8")
        self.assertIn("SUM(X)", source_text)
        self.assertIn("TT1(1)*TT2(2)", source_text)
        with tempfile.TemporaryDirectory(prefix="fortad-v419-exact-") as directory:
            scratch = Path(directory)
            diffsizes = compile_source(
                UPSTREAM / "nonRegressions" / "DIFFSIZES.f90",
                scratch / "diffsizes.o",
                scratch / "stored-mod",
            )
            primal = compile_source(
                SOURCE_DIR / "program.f90", scratch / "primal.o", scratch / "exact-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_Rd.f90",
                scratch / "stored.o",
                scratch / "stored-mod",
            )
        self.assertEqual(diffsizes.returncode, 0, diffsizes.stderr)
        self.assertNotEqual(primal.returncode, 0)
        self.assertIn("assumed size array", primal.stderr)
        self.assertNotEqual(stored.returncode, 0)
        self.assertIn("nonderived-type variable", stored.stderr)
        self.assertIn("isize1ofdrfaa", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compile_refusal(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v419-fresh-") as directory:
            scratch = Path(directory)
            for mode in ("p", "d", "b"):
                generated_dir = scratch / mode
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        f"-{mode}",
                        "-root",
                        "ROOT",
                        "-context",
                        "-association",
                        "byaddress",
                        "-O",
                        ".",
                        "-o",
                        "v419",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                source = generated_dir / f"v419_{mode}.f90"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((generated_dir / f"v419_{mode}.msg").is_file())
                module_dir = scratch / f"mod-{mode}"
                if mode != "p":
                    diffsizes = compile_source(
                        UPSTREAM / "nonRegressions" / "DIFFSIZES.f90",
                        scratch / f"diffsizes-{mode}.o",
                        module_dir,
                    )
                    self.assertEqual(diffsizes.returncode, 0, diffsizes.stderr)
                compiled = compile_source(
                    source, scratch / f"v419_{mode}.o", module_dir
                )
                self.assertNotEqual(compiled.returncode, 0, mode)
                diagnostic = compiled.stdout + compiled.stderr
                if mode == "p":
                    self.assertIn("assumed size array", diagnostic)
                elif mode == "d":
                    self.assertIn("isize1ofdrfaa", diagnostic)
                    self.assertIn("assumed size array", diagnostic)
                else:
                    self.assertIn("INTEGER*4", diagnostic)
                    self.assertIn("isize1ofdrfaa", diagnostic)

    def test_exact_fortad_refusals_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v419-fortad-") as directory:
            scratch = Path(directory)
            requests = {
                "parser": [
                    "check",
                    "--proc",
                    "ROOT",
                    "--output",
                    str(scratch / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "X",
                    "--proc",
                    "ROOT",
                    "--name",
                    "v419_forward",
                    "--module",
                    "v419_forward_mod",
                    "--output",
                    str(scratch / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "X",
                    "--dep",
                    "zz",
                    "--proc",
                    "ROOT",
                    "--name",
                    "v419_reverse",
                    "--module",
                    "v419_reverse_mod",
                    "--output",
                    str(scratch / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn(
                    "unsupported allocation lifetime construct 'allocatable declaration/component'",
                    completed.stderr,
                    mode,
                )
                self.assertFalse((scratch / f"{mode}.f90").exists())
        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("known_X_initialized_prefix_sum: 693.000000000000", oracle.stdout)
        self.assertIn("undefined_reads: TT1(1), TT2(2), X(21:30)", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
