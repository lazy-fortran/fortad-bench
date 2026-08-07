#!/usr/bin/env python3
"""Three behavioral tests for the pinned Tapenade v412 boundary case."""

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
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
if not UPSTREAM_ROOT.is_dir():
    UPSTREAM_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
if not FORTAD_ROOT.is_dir():
    FORTAD_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad")
SOURCE_DIR = UPSTREAM_ROOT / "todoF90" / "REFERENCES" / "v412"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM_ROOT / "bin" / "tapenade"
STRICT_FLAGS = [
    "-std=f2018", "-ffree-form", "-ffree-line-length-none", "-pedantic-errors",
    "-Wall", "-Wextra", "-Wimplicit-interface", "-cpp",
]


def run(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(list(args), cwd=cwd, capture_output=True, text=True, check=False)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compile_strict(source: Path, output: Path, module_dir: Path) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    return run("gfortran", *STRICT_FLAGS, f"-I{SOURCE_DIR}", f"-J{module_dir}",
               "-c", str(source), "-o", str(output))


class V412ContractTests(unittest.TestCase):
    def test_exact_upstream_strict_compile_behavior(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a")
        self.assertEqual(run("git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD").stdout.strip(), manifest["upstream_revision"])
        for name, expected in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(SOURCE_DIR / name), expected, name)

        with tempfile.TemporaryDirectory(prefix="fortad-v412-exact-") as directory:
            output = Path(directory)
            primal = compile_strict(SOURCE_DIR / "program.f90", output / "program.o", output / "program-mod")
            stored = compile_strict(SOURCE_DIR / "program_Rd.f90", output / "program_Rd.o", output / "rd-mod")
        self.assertNotEqual(primal.returncode, 0)
        self.assertRegex(primal.stderr, r"Return type mismatch|Type mismatch in argument")
        self.assertNotEqual(stored.returncode, 0)
        self.assertIn("Symbol ‘f0’ at (1) has no IMPLICIT type", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compile(self) -> None:
        self.assertEqual(run("git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD").stdout.strip(), "e59864cab441d4175df75383b3ff58c3dcd26df9")
        with tempfile.TemporaryDirectory(prefix="fortad-v412-tapenade-") as directory:
            output = Path(directory)
            modes = (("parser", "-p", "v412_p.f90"), ("forward", "-d", "v412_d.f90"), ("reverse", "-b", "v412_b.f90"))
            for label, mode, filename in modes:
                generated = run(str(TAPENADE), mode, "-root", "top", "-O", ".", "-o", "v412", str(SOURCE_DIR / "program.f90"), cwd=output)
                self.assertEqual(generated.returncode, 0, generated.stderr)
                source = output / filename
                self.assertTrue(source.is_file())
                self.assertTrue((output / filename.replace(".f90", ".msg")).is_file())
                compiled = compile_strict(source, output / f"{label}.o", output / f"{label}-mod")
                self.assertNotEqual(compiled.returncode, 0, label)
                self.assertIn("Type mismatch in argument", compiled.stderr, label)

    def test_exact_fortad_parser_forward_reverse_behavior(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        cases = (
            ("parser", ("check", "--proc", "top"), "parser.f90"),
            ("forward", ("--mode", "forward", "--indep", "x", "--proc", "top"), "forward.f90"),
            ("reverse", ("--mode", "reverse", "--indep", "x", "--dep", "y", "--proc", "top"), "reverse.f90"),
        )
        for mode, arguments, filename in cases:
            with tempfile.TemporaryDirectory(prefix=f"fortad-v412-{mode}-") as directory:
                output = Path(directory) / filename
                completed = run(str(FORTAD), *arguments, "--output", str(output), str(SOURCE_DIR / "program.f90"))
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn("fortad: unsupported statement at line 56", completed.stderr)
                self.assertFalse(output.exists(), mode)


if __name__ == "__main__":
    unittest.main(verbosity=1)
