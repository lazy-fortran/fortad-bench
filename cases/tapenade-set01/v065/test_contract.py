#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the v065 no-entry boundary."""

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
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
if not (UPSTREAM / ".git").exists():
    UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set02" / "v065"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
MANIFEST = CASE / "manifest.toml"
STRICT_FREE = [
    "-std=f2018",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-cpp",
]
STRICT_FIXED = [flag for flag in STRICT_FREE if flag != "-ffree-form"]
STRICT_FIXED.insert(1, "-ffixed-form")


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def compile_source(source: Path, output: Path, module_dir: Path, *, fixed: bool) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    flags = STRICT_FIXED if fixed else STRICT_FREE
    return run(
        [
            os.environ.get("FC", "gfortran"),
            *flags,
            f"-I{SOURCE_DIR}",
            f"-J{module_dir}",
            "-c",
            str(source),
            "-o",
            str(output),
        ]
    )


class V065ContractTests(unittest.TestCase):
    def test_tracked_inventory_and_strict_exact_reference_compilation(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-no-entry-point-reference-only")
        self.assertEqual(manifest["selected_entry_points"], [])
        self.assertEqual(manifest["stored_references"], ["program_p.f", "program_p.msg"])
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a")
        self.assertEqual(run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(), manifest["upstream_revision"])
        tracked = run(["git", "-C", str(UPSTREAM), "ls-files", "nonRegressions/set02/v065"]).stdout.splitlines()
        self.assertEqual(tracked, [
            "nonRegressions/set02/v065/program.f",
            "nonRegressions/set02/v065/program_p.f",
            "nonRegressions/set02/v065/program_p.msg",
        ])
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v065-compile-") as directory:
            output = Path(directory)
            primal = compile_source(SOURCE_DIR / "program.f", output / "program.o", output / "primal-mod", fixed=False)
            parser = compile_source(SOURCE_DIR / "program_p.f", output / "program_p.o", output / "parser-mod", fixed=True)
            self.assertEqual(primal.returncode, 0, primal.stderr)
            self.assertEqual(parser.returncode, 0, parser.stderr)

    def test_fresh_tapenade_no_root_probes_and_parser_compilation(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v065-tapenade-") as directory:
            output = Path(directory)
            for mode, flag, suffix in (("parser", "-p", "p"), ("tangent", "-d", "d"), ("reverse", "-b", "b")):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run(
                    [str(TAPENADE), flag, "-O", ".", "-o", "v065", str(SOURCE_DIR / "program.f")],
                    cwd=mode_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                self.assertTrue((mode_dir / f"v065_{suffix}.msg").is_file())
                if mode == "parser":
                    self.assertTrue((mode_dir / "v065_p.f").is_file())
                    compiled = compile_source(mode_dir / "v065_p.f", output / "parser.o", output / "parser-mod", fixed=True)
                    self.assertEqual(compiled.returncode, 0, compiled.stderr)
                else:
                    self.assertFalse((mode_dir / f"v065_{suffix}.f").exists())
                    self.assertIn("No root unit to differentiate", generated.stdout)

    def test_exact_fortad_no_entry_refusals_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v065-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": ["check", "--output", str(output / "parser.f90")],
                "forward": ["--mode", "forward", "--indep", "II", "--name", "v065_forward", "--output", str(output / "forward.f90")],
                "reverse": ["--mode", "reverse", "--indep", "II", "--dep", "JJ", "--name", "v065_reverse", "--output", str(output / "reverse.f90")],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f")])
                self.assertEqual(completed.returncode, 1, mode)
                self.assertIn("no function or subroutine found in source", completed.stderr, mode)
                self.assertFalse((output / f"{mode}.f90").exists())

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_common_values: [1, 2, 3]", oracle.stdout)
        self.assertIn("oracle_weighted_checksum: 14", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
