#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v414 case."""

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
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")
)
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v414"
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


def compile_source(
    source: Path, output: Path, module_dir: Path
) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    return subprocess.run(
        [
            os.environ.get("FC", "gfortran"),
            *FLAGS,
            f"-I{SOURCE_DIR}",
            f"-J{module_dir}",
            "-c",
            str(source),
            "-o",
            str(output),
        ],
        capture_output=True,
        text=True,
        check=False,
    )


class V414ContractTests(unittest.TestCase):
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
        source_text = (SOURCE_DIR / "program.f90").read_text()
        self.assertIn("addvector%x", source_text)
        self.assertNotIn("addvector%y =", source_text)
        with tempfile.TemporaryDirectory(prefix="fortad-v414-exact-") as directory:
            scratch = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", scratch / "primal.o", scratch / "primal-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_Rd.f90", scratch / "stored.o", scratch / "stored-mod"
            )
        self.assertEqual(primal.returncode, 0, primal.stderr)
        self.assertEqual(stored.returncode, 0, stored.stderr)
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_fresh_tapenade_generation_and_strict_compile(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v414-tapenade-") as directory:
            scratch = Path(directory)
            outputs = {
                "parser": ("-p", "v414_p.f90"),
                "forward": ("-d", "v414_d.f90"),
                "reverse": ("-b", "v414_b.f90"),
            }
            for mode, (flag, filename) in outputs.items():
                generated = scratch / mode
                generated.mkdir()
                result = subprocess.run(
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
                        "v414",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                source = generated / filename
                self.assertTrue(source.is_file(), source)
                self.assertTrue(
                    (generated / filename.replace(".f90", ".msg")).is_file()
                )
                compiled = compile_source(
                    source, scratch / f"{mode}.o", scratch / f"{mode}-mod"
                )
                self.assertEqual(compiled.returncode, 0, compiled.stderr)

    def test_exact_fortad_parser_forward_reverse_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v414-fortad-") as directory:
            scratch = Path(directory)
            requests = {
                "parser": [
                    "check",
                    "--proc",
                    "addvector",
                    "--output",
                    str(scratch / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "a%x,b%x",
                    "--proc",
                    "addvector",
                    "--name",
                    "v414_forward",
                    "--module",
                    "v414_forward_mod",
                    "--output",
                    str(scratch / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "a%x,b%x",
                    "--dep",
                    "addvector",
                    "--proc",
                    "addvector",
                    "--name",
                    "v414_reverse",
                    "--module",
                    "v414_reverse_mod",
                    "--output",
                    str(scratch / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                result = subprocess.run(
                    [str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                generated = scratch / f"{mode}.f90"
                self.assertTrue(generated.is_file(), generated)
                compiled = compile_source(
                    generated, scratch / f"{mode}.o", scratch / f"{mode}-mod"
                )
                self.assertNotEqual(compiled.returncode, 0, mode)
                diagnostic = compiled.stdout + compiled.stderr
                if mode == "parser":
                    self.assertIn("result()", generated.read_text())
                    self.assertIn("Derived type", diagnostic)
                elif mode == "forward":
                    self.assertIn(", , _d)", generated.read_text())
                    self.assertIn("Invalid character in name", diagnostic)
                else:
                    self.assertIn("addvector%x_b", generated.read_text())
                    self.assertIn("Derived type", diagnostic)

        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("finite_difference_max_error:", oracle.stdout)
        self.assertIn("adjoint_identity_residual:", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
