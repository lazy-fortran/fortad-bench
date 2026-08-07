#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v425 boundary."""

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
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v425"
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


class V425ContractTests(unittest.TestCase):
    def test_exact_upstream_strict_compile_and_stored_reference(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-without-port")
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
        with tempfile.TemporaryDirectory(prefix="fortad-v425-exact-") as directory:
            output = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", output / "primal.o", output / "primal-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_Rd.f90", output / "stored.o", output / "stored-mod"
            )
        self.assertEqual(primal.returncode, 0, primal.stdout + primal.stderr)
        self.assertEqual(stored.returncode, 0, stored.stdout + stored.stderr)
        self.assertIn("LEN(TRIM(fichier))", (SOURCE_DIR / "program.f90").read_text())
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_fresh_tapenade_generation_and_strict_compile(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v425-tapenade-") as directory:
            output = Path(directory)
            for mode, flag, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                generated_dir = output / mode
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        "-association",
                        "byaddress",
                        flag,
                        "-root",
                        "addvector",
                        "-O",
                        ".",
                        "-o",
                        "v425",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = generated_dir / f"v425_{suffix}.f90"
                self.assertTrue(source.is_file(), source)
                self.assertTrue(generated_dir.joinpath(f"v425_{suffix}.msg").is_file())
                compiled = compile_source(
                    source, output / f"v425-{mode}.o", output / f"mod-{mode}"
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_exact_fortad_refusals_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v425-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": [
                    "check",
                    "--proc",
                    "addvector",
                    "--output",
                    str(output / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "a%w%x(1),b%w%x(2)",
                    "--proc",
                    "addvector",
                    "--name",
                    "v425_forward",
                    "--module",
                    "v425_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "a%w%x(1),b%w%x(2)",
                    "--dep",
                    "c%w%x(1)",
                    "--proc",
                    "addvector",
                    "--name",
                    "v425_reverse",
                    "--module",
                    "v425_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                diagnostic = completed.stdout + completed.stderr
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn("unsupported statement at line 1", diagnostic, mode)
                self.assertFalse((output / f"{mode}.f90").exists())
        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("finite_difference_max_error:", oracle.stdout)
        self.assertIn("adjoint_identity_residual:", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
