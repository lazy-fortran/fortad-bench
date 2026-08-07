#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v075 boundary."""

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
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set05" / "v075"
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


def compile_source(
    source: Path, output: Path, module_dir: Path
) -> subprocess.CompletedProcess[str]:
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


class V075ContractTests(unittest.TestCase):
    def test_exact_source_and_stored_reference_strict_boundary(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-module-only-no-entry")
        self.assertEqual(manifest["selected_entry_points"], [])
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
            manifest["upstream_revision"],
        )
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v075-exact-") as directory:
            output = Path(directory)
            exact = compile_source(
                SOURCE_DIR / "program.f90", output / "program.o", output / "exact-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_p.f90", output / "program_p.o", output / "stored-mod"
            )
        self.assertEqual(exact.returncode, 0, exact.stderr)
        self.assertNotEqual(stored.returncode, 0)
        self.assertIn("Nonstandard type declaration INTEGER*4", stored.stderr)

    def test_fresh_tapenade_no_root_generation_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v075-tapenade-") as directory:
            output = Path(directory)
            modes = (("parser", "-p", "v075_p.f90"), ("forward", "-d", "v075_d.f90"), ("reverse", "-b", "v075_b.f90"))
            for mode, flag, source_name in modes:
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        flag,
                        "-O",
                        ".",
                        "-o",
                        "v075",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=mode_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                self.assertTrue((mode_dir / f"v075_{flag[1:]}.msg").is_file())
                if mode == "parser":
                    self.assertTrue((mode_dir / source_name).is_file())
                    compiled = compile_source(
                        mode_dir / source_name, output / "parser.o", output / "parser-mod"
                    )
                    self.assertNotEqual(compiled.returncode, 0)
                    self.assertIn("Nonstandard type declaration INTEGER*4", compiled.stderr)
                else:
                    self.assertFalse((mode_dir / source_name).exists())
                    self.assertIn("No root unit to differentiate", generated.stdout)
                    self.assertIn("The code provided does not contain a top procedure", generated.stdout)

    def test_exact_fortad_no_entry_refusal_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v075-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": [
                    "check",
                    "--output",
                    str(output / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "block_id",
                    "--dep",
                    "block_id",
                    "--name",
                    "v075_forward",
                    "--module",
                    "v075_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "block_id",
                    "--dep",
                    "block_id",
                    "--name",
                    "v075_reverse",
                    "--module",
                    "v075_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertEqual(completed.returncode, 1, mode)
                self.assertIn("no function or subroutine found in source", completed.stderr, mode)
                self.assertFalse((output / f"{mode}.f90").exists())

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_component_count: 19", oracle.stdout)
        self.assertIn("oracle_layout_weighted_checksum: 26043", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
