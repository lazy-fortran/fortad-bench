#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v413 corpus boundary."""

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
UPSTREAM = Path(
    os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade"))
)
if not UPSTREAM.is_dir():
    UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", str(ROOT.parent / "fortad"))
)
if not FORTAD_ROOT.is_dir():
    FORTAD_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad")
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v413"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
FC = os.environ.get("FC", "gfortran")
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


def compile_strict(source: Path, output: Path, module_dir: Path) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True)
    return subprocess.run(
        [
            FC,
            *STRICT_FLAGS,
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


class V413ContractTests(unittest.TestCase):
    def test_exact_upstream_strict_compile_and_semantic_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        for relative, expected in manifest["upstream_sha256"].items():
            source = SOURCE_DIR / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), expected)

        with tempfile.TemporaryDirectory(prefix="fortad-v413-exact-") as directory:
            output = Path(directory)
            primal = compile_strict(
                SOURCE_DIR / "program.f90", output / "program.o", output / "primal-mod"
            )
            stored = compile_strict(
                SOURCE_DIR / "program_Rd.f90",
                output / "program_Rd.o",
                output / "stored-mod",
            )
        self.assertEqual(primal.returncode, 0, primal.stderr)
        self.assertEqual(stored.returncode, 0, stored.stderr)
        self.assertIn("is used uninitialized", primal.stderr)
        self.assertIn("is used uninitialized", stored.stderr)
        self.assertIn(
            "variable mt is used before initialized",
            (SOURCE_DIR / "program_Rd.msg").read_text(encoding="utf-8"),
        )
        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("oracle_status: pass", oracle.stdout)

    def test_fresh_tapenade_generation_and_strict_compile(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-v413-fresh-") as directory:
            output = Path(directory)
            for label, option, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                generated_dir = output / label
                generated_dir.mkdir()
                generated = subprocess.run(
                    [
                        str(UPSTREAM / "bin" / "tapenade"),
                        option,
                        "-root",
                        "f4",
                        "-O",
                        ".",
                        "-o",
                        "v413",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                source = generated_dir / f"v413_{suffix}.f90"
                message = generated_dir / f"v413_{suffix}.msg"
                self.assertTrue(source.is_file())
                self.assertTrue(message.is_file())
                self.assertIn("variable mt is used before initialized", message.read_text())
                compiled = compile_strict(
                    source, output / f"{label}.o", output / f"{label}-mod"
                )
                self.assertEqual(compiled.returncode, 0, compiled.stderr)
                self.assertIn("is used uninitialized", compiled.stderr)

    def test_exact_fortad_parser_forward_reverse_refusal(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v413-exact-") as directory:
            output = Path(directory)
            commands = (
                (
                    "parser",
                    [
                        str(FORTAD),
                        "check",
                        "--proc",
                        "f4",
                        "--output",
                        str(output / "parser.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
                (
                    "forward",
                    [
                        str(FORTAD),
                        "--mode",
                        "forward",
                        "--proc",
                        "f4",
                        "--indep",
                        "hr",
                        "--name",
                        "f4_d",
                        "--module",
                        "v413_forward_mod",
                        "--output",
                        str(output / "forward.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
                (
                    "reverse",
                    [
                        str(FORTAD),
                        "--mode",
                        "reverse",
                        "--proc",
                        "f4",
                        "--indep",
                        "hr",
                        "--dep",
                        "f4",
                        "--name",
                        "f4_b",
                        "--module",
                        "v413_reverse_mod",
                        "--output",
                        str(output / "reverse.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
            )
            for label, command in commands:
                completed = subprocess.run(
                    command, capture_output=True, text=True, check=False
                )
                self.assertNotEqual(completed.returncode, 0, label)
                self.assertIn("unsupported statement at line 6", completed.stderr)
                self.assertFalse((output / f"{label}.f90").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
