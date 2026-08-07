#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v503 boundary."""

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
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")
)
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v503"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
MANIFEST = CASE / "manifest.toml"
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


class V503ContractTests(unittest.TestCase):
    def test_exact_upstream_strict_refusal_and_no_stored_reference(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"], "expected-refusal-invalid-incomplete-upstream"
        )
        self.assertEqual(manifest["stored_references"], [])
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
        self.assertTrue((SOURCE_DIR / "program.f90").is_file())
        for name in ("Options", "program_d.f90", "program_d.msg", "program_b.f90", "program_b.msg"):
            self.assertFalse((SOURCE_DIR / name).exists(), name)
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

        with tempfile.TemporaryDirectory(prefix="fortad-v503-exact-") as directory:
            output = Path(directory)
            completed = compile_source(
                SOURCE_DIR / "program.f90", output / "program.o", output / "mod"
            )
        diagnostic = completed.stdout + completed.stderr
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("Allocate-object", diagnostic)
        self.assertIn("neither a data pointer nor an allocatable variable", diagnostic)

    def test_fresh_tapenade_generation_and_applicable_compile(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v503-tapenade-") as directory:
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
                        "SYSTEME",
                        "-O",
                        ".",
                        "-o",
                        "v503",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=mode_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                self.assertTrue((mode_dir / f"v503_{suffix}.msg").is_file())
                if mode == "parser":
                    source = mode_dir / "v503_p.f90"
                    self.assertTrue(source.is_file(), source)
                    compiled = compile_source(
                        source, output / "parser.o", output / "parser-mod"
                    )
                    self.assertNotEqual(compiled.returncode, 0)
                    diagnostic = compiled.stdout + compiled.stderr
                    self.assertIn("not a variable", diagnostic)
                    self.assertIn("not been declared", diagnostic)
                else:
                    self.assertFalse((mode_dir / f"v503_{suffix}.f90").exists())
                    self.assertIn(
                        "no active input nor output",
                        (mode_dir / f"v503_{suffix}.msg").read_text(),
                    )

    def test_exact_fortad_refusals_and_independent_semantic_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v503-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": [
                    "check",
                    "--proc",
                    "SYSTEME",
                    "--output",
                    str(output / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "X",
                    "--dep",
                    "Q",
                    "--proc",
                    "SYSTEME",
                    "--name",
                    "v503_forward",
                    "--module",
                    "v503_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "X",
                    "--dep",
                    "Q",
                    "--proc",
                    "SYSTEME",
                    "--name",
                    "v503_reverse",
                    "--module",
                    "v503_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                diagnostic = completed.stdout + completed.stderr
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn(
                    "unsupported allocation lifetime construct 'allocate' at line 80",
                    diagnostic,
                    mode,
                )
                self.assertFalse((output / f"{mode}.f90").exists())

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_first_reachable_event: allocate SVRAI(size(X))", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
