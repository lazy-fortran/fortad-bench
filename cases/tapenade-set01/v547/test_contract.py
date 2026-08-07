#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v547 boundary."""

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
DEFAULT_UPSTREAM = BENCH / "upstream" / "tapenade"
if not DEFAULT_UPSTREAM.is_dir():
    DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v547"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
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
    module_dir.mkdir(parents=True, exist_ok=True)
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


class V547ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_reference_strict_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-invalid-stored-derivatives-and-fortad-binding-label",
        )
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["upstream_revision"],
        )
        self.assertEqual(
            run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["fortad_revision"],
        )
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)
        with tempfile.TemporaryDirectory(prefix="fortad-v547-exact-") as directory:
            output = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", output / "primal.o", output / "primal-mod"
            )
            stored_p = compile_source(
                SOURCE_DIR / "program_p.f90", output / "stored-p.o", output / "stored-p-mod"
            )
            stored_b = compile_source(
                SOURCE_DIR / "program_b.f90", output / "stored-b.o", output / "stored-b-mod"
            )
        self.assertEqual(primal.returncode, 0, primal.stdout + primal.stderr)
        for stored in (stored_p, stored_b):
            self.assertNotEqual(stored.returncode, 0, stored.stdout + stored.stderr)
            self.assertIn("GNU Extension: Nonstandard type declaration", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compile_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v547-tapenade-") as directory:
            output = Path(directory)
            for mode in ("p", "d", "b"):
                generated = output / mode
                generated.mkdir()
                result = run(
                    [
                        str(TAPENADE),
                        "-head",
                        "endval(endval)/(bb)",
                        f"-{mode}",
                        "-O",
                        ".",
                        "-o",
                        "v547",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                source = generated / f"v547_{mode}.f90"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((generated / f"v547_{mode}.msg").is_file())
                compiled = compile_source(
                    source, output / f"generated-{mode}.o", output / f"generated-{mode}-mod"
                )
                self.assertNotEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                self.assertIn("GNU Extension: Nonstandard type declaration", compiled.stderr)

    def test_exact_fortad_refusal_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v547-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": [
                    "check",
                    "--proc",
                    "endval",
                    "--output",
                    str(output / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "bb",
                    "--dep",
                    "endval",
                    "--proc",
                    "endval",
                    "--name",
                    "v547_forward",
                    "--module",
                    "v547_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "bb",
                    "--dep",
                    "endval",
                    "--proc",
                    "endval",
                    "--name",
                    "v547_reverse",
                    "--module",
                    "v547_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                result = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertNotEqual(result.returncode, 0, mode)
                self.assertIn(
                    "Missing closing paren for binding label at line 62, column 25",
                    result.stdout + result.stderr,
                    mode,
                )
                self.assertFalse((output / f"{mode}.f90").exists())
        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("finite_difference_max_error:", oracle.stdout)
        self.assertIn("adjoint_identity_residual:", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
