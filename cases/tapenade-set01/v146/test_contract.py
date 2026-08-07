#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the v146 no-entry boundary."""

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
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set05" / "v146"
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class V146ContractTests(unittest.TestCase):
    def test_static_inventory_is_module_only_and_reference_shaped(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-no-entry-point-reference-only")
        self.assertEqual(manifest["selected_entry_points"], [])
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a")
        for name, digest in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(SOURCE_DIR / name), digest, name)
        source = (SOURCE_DIR / "program.f90").read_text(encoding="utf-8").lower()
        self.assertIn("module a", source)
        self.assertNotRegex(source, r"^\s*(program|subroutine|function)\b")
        self.assertNotIn("contains", source)
        self.assertIn("nonRegressions/set05/v146/program_p.f90", manifest["stored_references"])
        self.assertIn("no transformable procedure", manifest["closure"].lower())

    def test_strict_sources_and_fresh_tapenade_preserve_the_boundary(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-v146-tapenade-") as directory:
            output = Path(directory)
            for label, source in (("primal", "program.f90"), ("reference", "program_p.f90")):
                completed = subprocess.run(
                    ["gfortran", *STRICT_FLAGS, f"-J{output / label}", "-c", str(SOURCE_DIR / source), "-o", str(output / f"{label}.o")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                diagnostic = completed.stdout + completed.stderr
                self.assertNotEqual(completed.returncode, 0, label)
                self.assertIn("Kind 2 not supported for type REAL", diagnostic)
                self.assertIn("exponent and an explicit kind", diagnostic)

            for mode, option, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = subprocess.run(
                    [str(TAPENADE), option, "-root", "A", "-O", ".", "-o", "v146", str(SOURCE_DIR / "program.f90")],
                    cwd=mode_dir,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                message = mode_dir / f"v146_{suffix}.msg"
                self.assertTrue(message.is_file(), message)
                if mode == "parser":
                    self.assertTrue((mode_dir / "v146_p.f90").is_file())
                    self.assertIn("not a standard procedure", (generated.stdout + generated.stderr).lower())
                else:
                    self.assertFalse((mode_dir / f"v146_{suffix}.f90").exists())
                    self.assertIn("no root unit to differentiate", (generated.stdout + generated.stderr).lower())

    def test_fortad_no_procedure_boundary_and_independent_semantic_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v146-fortad-") as directory:
            output = Path(directory)
            requests = (
                ("parser", ["check", "--proc", "A", "--output", str(output / "parser.f90")]),
                ("forward", ["--mode", "forward", "--proc", "A", "--indep", "epsil", "--output", str(output / "forward.f90")]),
                ("reverse", ["--mode", "reverse", "--proc", "A", "--indep", "epsil", "--dep", "epsil", "--output", str(output / "reverse.f90")]),
            )
            for label, arguments in requests:
                completed = subprocess.run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")], capture_output=True, text=True, check=False)
                self.assertNotEqual(completed.returncode, 0, label)
                self.assertIn("no procedure named 'A' in this source", completed.stderr, label)
                self.assertFalse((output / f"{label}.f90").exists(), label)
        oracle = subprocess.run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")], capture_output=True, text=True, check=True)
        self.assertIn("oracle_status: pass classification=module-only-no-entry-point", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
