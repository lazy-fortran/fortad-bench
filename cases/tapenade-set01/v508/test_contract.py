#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v508 boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
DEFAULT_UPSTREAM = ROOT / "upstream" / "tapenade"
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
FORTAD_REPO = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v508"
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compile_source(
    source: Path,
    output: Path,
    module_dir: Path,
    *extra: str,
) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    return run(
        [
            FC,
            *FLAGS,
            f"-I{SOURCE_DIR}",
            *extra,
            f"-J{module_dir}",
            "-c",
            str(source),
            "-o",
            str(output),
        ]
    )


class V508ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_reference_strict_compilation(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-external-inout-global-state-and-codegen",
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
            manifest["upstream_revision"],
        )
        self.assertEqual(
            run(["git", "-C", str(FORTAD_REPO), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["fortad_revision"],
        )
        for relative, expected in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(UPSTREAM / relative), expected, relative)
        for absent in ("program_p.f90", "program_p.msg", "program_b.f90", "program_b.msg"):
            self.assertFalse((SOURCE_DIR / absent).exists(), absent)

        with tempfile.TemporaryDirectory(prefix="fortad-v508-exact-") as directory:
            output = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", output / "program.o", output / "primal-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_d.f90",
                output / "program_d.o",
                output / "stored-mod",
            )
        self.assertEqual(primal.returncode, 0, primal.stdout + primal.stderr)
        self.assertEqual(stored.returncode, 0, stored.stdout + stored.stderr)
        self.assertIn("implicit interface", primal.stderr)
        self.assertIn("implicit interface", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compile_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v508-fresh-") as directory:
            output = Path(directory)
            for mode, suffix in (("p", "parser"), ("d", "forward"), ("b", "reverse")):
                generated_dir = output / suffix
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        f"-{mode}",
                        "-head",
                        "top",
                        "-head",
                        "compute",
                        "-O",
                        ".",
                        "-o",
                        "v508",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = generated_dir / f"v508_{mode}.f90"
                self.assertTrue(source.is_file())
                self.assertTrue((generated_dir / f"v508_{mode}.msg").is_file())
                compiled = compile_source(
                    source, output / f"v508_{mode}.o", output / f"mod-{suffix}"
                )
                if mode in ("p", "d"):
                    self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                else:
                    self.assertNotEqual(compiled.returncode, 0)
                    self.assertIn("compute_b", compiled.stderr.lower())

    def test_exact_fortad_codegen_boundary_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v508-fortad-") as directory:
            output = Path(directory)
            exact_mod = output / "exact-mod"
            exact = compile_source(SOURCE_DIR / "program.f90", output / "exact.o", exact_mod)
            self.assertEqual(exact.returncode, 0, exact.stdout + exact.stderr)

            parser = run(
                [
                    str(FORTAD),
                    "check",
                    "--proc",
                    "top",
                    "--output",
                    str(output / "parser.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ]
            )
            self.assertEqual(parser.returncode, 0, parser.stdout + parser.stderr)
            self.assertTrue((output / "parser.f90").is_file())
            parser_compile = compile_source(
                output / "parser.f90", output / "parser.o", output / "parser-mod", f"-I{exact_mod}"
            )
            self.assertNotEqual(parser_compile.returncode, 0)
            self.assertIn("Invalid character in name", parser_compile.stderr)

            forward = run(
                [
                    str(FORTAD),
                    "--mode",
                    "forward",
                    "--indep",
                    "r,s",
                    "--dep",
                    "top",
                    "--proc",
                    "top",
                    "--name",
                    "v508_forward",
                    "--module",
                    "v508_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ]
            )
            self.assertEqual(forward.returncode, 0, forward.stdout + forward.stderr)
            self.assertTrue((output / "forward.f90").is_file())
            forward_compile = compile_source(
                output / "forward.f90", output / "forward.o", output / "forward-mod", f"-I{exact_mod}"
            )
            self.assertNotEqual(forward_compile.returncode, 0)
            self.assertIn("Invalid character in name", forward_compile.stderr)

            reverse = run(
                [
                    str(FORTAD),
                    "--mode",
                    "reverse",
                    "--indep",
                    "r,s",
                    "--dep",
                    "top",
                    "--proc",
                    "top",
                    "--name",
                    "v508_reverse",
                    "--module",
                    "v508_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ]
            )
            self.assertNotEqual(reverse.returncode, 0)
            self.assertFalse((output / "reverse.f90").exists())
            self.assertIn("assignment to undeclared 'y'", reverse.stderr)

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_status: pass", oracle.stdout)
        self.assertIn("adjoint_identity_residual=", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
