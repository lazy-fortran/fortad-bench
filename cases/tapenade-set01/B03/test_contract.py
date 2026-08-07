#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned B03 boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from oracle import check_jvp, check_vjp, source_shape


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "B03"
SOURCE = SOURCE_DIR / "program.f"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
STRICT_FLAGS = [
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fno-lto",
    "-fsyntax-only",
]
LEGACY_FLAGS = [
    "-std=legacy",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fno-lto",
    "-fsyntax-only",
]


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def compile_source(source: Path, flags: list[str]) -> subprocess.CompletedProcess[str]:
    return run([os.environ.get("FC", "gfortran"), *flags, str(source)])


class B03ContractTests(unittest.TestCase):
    def test_exact_and_stored_sources_are_pinned_and_legacy_only(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-fortad-unsupported-common-line-33")
        self.assertEqual(manifest["upstream_entry_point"].split("(", 1)[0], "viscflux")
        self.assertEqual(manifest["independent"], ["qpi2", "fn", "vres6", "qli1", "qli2", "qi1", "qi2", "qpi1"])
        self.assertEqual(manifest["dependent"], ["fn", "vres6"])
        self.assertEqual(manifest["stored_references"], [
            "program_p.f", "program_p.msg", "program_d.f", "program_d.msg", "program_b.f", "program_b.msg"
        ])
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "8137837b6c474708c20ea86ad02b086aa15322fd")
        self.assertEqual(run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(), manifest["upstream_revision"])
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            if digest != "recorded-by-runner":
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest, relative)
        source_shape(SOURCE)
        for name in ("program.f", "program_p.f", "program_d.f", "program_b.f"):
            self.assertEqual(compile_source(SOURCE_DIR / name, STRICT_FLAGS).returncode, 1, name)
            self.assertEqual(compile_source(SOURCE_DIR / name, LEGACY_FLAGS).returncode, 0, name)

    def test_fresh_tapenade_generation_has_both_compiler_boundaries(self) -> None:
        check_jvp()
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-b03b01-tapenade-") as directory:
            output = Path(directory)
            for mode, flag, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run(
                    [str(TAPENADE), flag, "-root", "viscflux", "-O", str(mode_dir), "-o", "b03b01", str(SOURCE)]
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                source = mode_dir / f"b03b01_{suffix}.f"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((mode_dir / f"b03b01_{suffix}.msg").is_file())
                self.assertEqual(compile_source(source, STRICT_FLAGS).returncode, 1, mode)
                self.assertEqual(compile_source(source, LEGACY_FLAGS).returncode, 0, mode)

    def test_exact_fortad_refuses_common_without_output_and_vjp_oracle_passes(self) -> None:
        check_vjp()
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-b03b01-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": ["check", "--proc", "viscflux", "--output", str(output / "parser.f90")],
                "forward": [
                    "--mode", "forward", "--proc", "viscflux", "--indep",
                    "qpi1,qi1,qli1,qi2,qli2,qpi2,vres6,fn", "--dep", "fn",
                    "--name", "b03b01_jvp", "--output", str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode", "reverse", "--proc", "viscflux", "--indep",
                    "qpi1,qi1,qli1,qi2,qli2,qpi2,vres6,fn", "--dep", "fn",
                    "--name", "b03b01_vjp", "--output", str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE)])
                self.assertEqual(completed.returncode, 1, completed.stderr)
                self.assertEqual(completed.stderr.strip(), "fortad: unsupported statement at line 33", mode)
                self.assertFalse((output / f"{mode}.f90").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
