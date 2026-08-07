#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the v147 no-entry boundary."""

from __future__ import annotations

import hashlib
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
if not FORTAD_ROOT.is_dir() and Path("/mnt/storage/code/lazy-fortran/fortad").is_dir():
    FORTAD_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad")
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set05" / "v147"
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
EXPECTED_HASHES = {
    "program.f90": "71b264c547882d35a2de081d3481da2135dcce16e0130f9ed7b492803c549105",
    "program_p.f90": "77898cb7a66ff67b4c8da01f4de962379a6600a624250f9d494c8d1704c1aacc",
    "program_p.msg": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class V147ContractTests(unittest.TestCase):
    def test_static_inventory_is_module_only_and_reference_shaped(self) -> None:
        source = (SOURCE_DIR / "program.f90").read_text(encoding="utf-8")
        reference = (SOURCE_DIR / "program_p.f90").read_text(encoding="utf-8")
        for name, digest in EXPECTED_HASHES.items():
            self.assertEqual(sha256(SOURCE_DIR / name), digest, name)
        self.assertEqual(re.findall(r"^\s*module\s+(?!procedure\b)(\w+)", source, re.I | re.M), ["a"])
        self.assertEqual(re.findall(r"^\s*module\s+(?!procedure\b)(\w+)", reference, re.I | re.M), ["A"])
        self.assertNotRegex(source, r"^\s*(?:program|subroutine|function)\b")
        self.assertNotRegex(reference, r"^\s*(?:program|subroutine|function)\b")
        self.assertNotRegex(source, r"^\s*contains\b")
        self.assertIn("logical, dimension(:), pointer :: iCo", source)
        self.assertIn("type BCDataType", source)
        self.assertIn("type(BCDataType), dimension(:), pointer :: BCData", source)

    def test_strict_sources_and_fresh_tapenade_preserve_the_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v147-tapenade-") as directory:
            output = Path(directory)
            for label, source in (("primal", "program.f90"), ("reference", "program_p.f90")):
                module_dir = output / f"mod-{label}"
                module_dir.mkdir()
                completed = subprocess.run(
                    ["gfortran", *STRICT_FLAGS, f"-J{module_dir}", "-c", str(SOURCE_DIR / source), "-o", str(output / f"{label}.o")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertTrue((output / f"{label}.o").is_file(), label)

            for mode, option, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = subprocess.run(
                    [str(TAPENADE), option, "-root", "A", "-O", ".", "-o", "v147", str(SOURCE_DIR / "program.f90")],
                    cwd=mode_dir,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                transcript = generated.stdout + generated.stderr
                message = mode_dir / f"v147_{suffix}.msg"
                self.assertTrue(message.is_file(), message)
                if mode == "parser":
                    self.assertTrue((mode_dir / "v147_p.f90").is_file())
                    self.assertIn("not a standard procedure", transcript.lower())
                    self.assertNotRegex((mode_dir / "v147_p.f90").read_text(encoding="utf-8"), r"^\s*(?:program|subroutine|function)\b")
                else:
                    self.assertFalse((mode_dir / f"v147_{suffix}.f90").exists())
                    self.assertIn("no root unit to differentiate", transcript.lower())
                    self.assertIn("code provided does not contain a top procedure", transcript.lower())

    def test_fortad_no_procedure_boundary_and_independent_semantic_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v147-fortad-") as directory:
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
        self.assertIn("oracle_status: pass classification=module-only-no-entry-point boundary=data-only-pointer-module", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
