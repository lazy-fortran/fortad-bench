#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v201 boundary."""

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
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
if not FORTAD_ROOT.is_dir() and Path("/mnt/storage/code/lazy-fortran/fortad").is_dir():
    FORTAD_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad")
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set05" / "v201"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
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


def compile_source(source: Path, output: Path, module_dir: Path) -> subprocess.CompletedProcess[str]:
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class V201ContractTests(unittest.TestCase):
    def test_exact_source_and_stored_parser_strict_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-module-only-no-entry")
        self.assertEqual(manifest["selected_entry_points"], [])
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "3a946d34d3caa7a75fb6f891139023650b4ce51a")
        self.assertEqual(run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(), manifest["upstream_revision"])
        for relative, digest in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(UPSTREAM / relative), digest, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v201-exact-") as directory:
            output = Path(directory)
            primal = compile_source(SOURCE_DIR / "program.f90", output / "primal.o", output / "primal-mod")
            stored = compile_source(SOURCE_DIR / "program_p.f90", output / "stored.o", output / "stored-mod")
        self.assertNotEqual(primal.returncode, 0)
        self.assertIn("Nonconforming tab character", primal.stderr)
        self.assertIn("Nonstandard type declaration INTEGER*4", primal.stderr)
        self.assertNotEqual(stored.returncode, 0)
        self.assertIn("Nonstandard type declaration INTEGER*4", stored.stderr)
        self.assertIn("Nonstandard type declaration REAL*8", stored.stderr)

    def test_fresh_tapenade_no_root_generation_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v201-tapenade-") as directory:
            output = Path(directory)
            requests = {"parser": ("-p", "v201_p.f90"), "forward": ("-d", "v201_d.f90"), "reverse": ("-b", "v201_b.f90")}
            for mode, (option, filename) in requests.items():
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run([str(TAPENADE), option, "-O", ".", "-o", "v201", str(SOURCE_DIR / "program.f90")], cwd=mode_dir)
                self.assertEqual(generated.returncode, 0, generated.stderr)
                message = mode_dir / filename.replace(".f90", ".msg")
                self.assertTrue(message.is_file(), message)
                if mode == "parser":
                    source = mode_dir / filename
                    self.assertTrue(source.is_file(), source)
                    compiled = compile_source(source, output / "parser.o", output / "parser-mod")
                    self.assertNotEqual(compiled.returncode, 0)
                    self.assertIn("Nonstandard type declaration INTEGER*4", compiled.stderr)
                    self.assertEqual(message.read_bytes(), (SOURCE_DIR / "program_p.msg").read_bytes())
                else:
                    self.assertFalse((mode_dir / filename).exists())
                    diagnostic = generated.stdout + generated.stderr
                    self.assertIn("No root unit to differentiate", diagnostic)
                    self.assertIn("The code provided does not contain a top procedure", message.read_text())

    def test_fortad_no_procedure_boundary_and_independent_layout_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v201-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": ["check", "--output", str(output / "parser.f90")],
                "forward": ["--mode", "forward", "--indep", "acoef1", "--name", "v201_forward", "--module", "v201_forward_mod", "--output", str(output / "forward.f90")],
                "reverse": ["--mode", "reverse", "--indep", "acoef1", "--dep", "acoef1", "--name", "v201_reverse", "--module", "v201_reverse_mod", "--output", str(output / "reverse.f90")],
            }
            for label, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertNotEqual(completed.returncode, 0, label)
                self.assertIn("fortad: no function or subroutine found in source", completed.stderr, label)
                self.assertFalse((output / f"{label}.f90").exists(), label)

        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_real_element_count: 3973969", oracle.stdout)
        self.assertIn("oracle_shape_checksum: 3985939", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
