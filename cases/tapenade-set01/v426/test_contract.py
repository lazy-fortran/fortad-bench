#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v426 boundary."""

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
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v426"
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


def fortad(*arguments: str) -> subprocess.CompletedProcess[str]:
    return run(["fo", "exec", "--no-build", "fortad", *arguments], cwd=FORTAD_REPO)


class V426ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_references_strict_compile(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"], "expected-refusal-unsupported-allocatable-lifetime"
        )
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["upstream_revision"],
        )
        self.assertEqual(
            run(["git", "-C", str(FORTAD_REPO), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["fortad_revision"],
        )
        for name, expected in manifest["upstream_sha256"].items():
            source = SOURCE_DIR / name
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), expected, name)
        self.assertEqual(
            (SOURCE_DIR / "Options").read_text(encoding="utf-8").strip(),
            "-root head -vars inputs -outvars outputs -context -noisize -association byaddress",
        )

        with tempfile.TemporaryDirectory(prefix="fortad-v426-exact-") as directory:
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

    def test_fresh_tapenade_generation_and_strict_compilation(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v426-tapenade-") as directory:
            output = Path(directory)
            for mode, suffix in (("parser", "p"), ("tangent", "d"), ("reverse", "b")):
                generated_dir = output / mode
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        "-association",
                        "byaddress",
                        "-vars",
                        "inputs",
                        "-outvars",
                        "outputs",
                        "-context",
                        "-noisize",
                        f"-{suffix}",
                        "-root",
                        "head",
                        "-O",
                        ".",
                        "-o",
                        "v426",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = generated_dir / f"v426_{suffix}.f90"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((generated_dir / f"v426_{suffix}.msg").is_file())
                compiled = compile_source(
                    source, output / f"{mode}.o", output / f"{mode}-mod"
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_exact_fortad_refusals_and_independent_oracle(self) -> None:
        self.assertTrue((FORTAD_REPO / "build" / "fo" / "bin" / "fortad").is_file())
        with tempfile.TemporaryDirectory(prefix="fortad-v426-fortad-") as directory:
            output = Path(directory)
            requests = (
                (
                    "parser",
                    [
                        "check",
                        "--proc",
                        "head",
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
                        "tDataIn,inputs",
                        "--proc",
                        "head",
                        "--name",
                        "v426_forward",
                        "--module",
                        "v426_forward_mod",
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
                        "tDataIn,inputs",
                        "--dep",
                        "outputs",
                        "--proc",
                        "head",
                        "--name",
                        "v426_reverse",
                        "--module",
                        "v426_reverse_mod",
                        "--output",
                        str(output / "reverse.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
            )
            for mode, arguments in requests:
                transformed = fortad(*arguments)
                self.assertNotEqual(transformed.returncode, 0, mode)
                self.assertIn(
                    "unsupported allocation lifetime construct 'allocatable declaration/component' at line 4",
                    transformed.stderr,
                    mode,
                )
                self.assertFalse((output / f"{mode}.f90").exists(), mode)

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_status: pass", oracle.stdout)
        self.assertIn("finite_difference_max_error:", oracle.stdout)
        self.assertIn("adjoint_identity_residual:", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
