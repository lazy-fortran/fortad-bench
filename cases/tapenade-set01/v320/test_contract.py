#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the v320 no-entry boundary."""

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
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set06" / "v320"
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


class V320ContractTests(unittest.TestCase):
    def test_exact_sources_compile_and_independent_semantic_oracle(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-no-entry-point-module-only")
        self.assertEqual(manifest["selected_entry_points"], [])
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "3a946d34d3caa7a75fb6f891139023650b4ce51a")
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["upstream_revision"],
        )
        self.assertEqual(
            run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["fortad_revision"],
        )
        tracked = run(
            ["git", "-C", str(UPSTREAM), "ls-files", "nonRegressions/set06/v320"]
        ).stdout.splitlines()
        self.assertEqual(
            tracked,
            [
                "nonRegressions/set06/v320/program.f90",
                "nonRegressions/set06/v320/program_p.f90",
                "nonRegressions/set06/v320/program_p.msg",
            ],
        )
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v320-exact-") as directory:
            output = Path(directory)
            for label, name in (("primal", "program.f90"), ("reference", "program_p.f90")):
                module_dir = output / f"{label}-mod"
                module_dir.mkdir()
                compiled = run(
                    [
                        os.environ.get("FC", "gfortran"),
                        *STRICT_FLAGS,
                        f"-I{SOURCE_DIR}",
                        f"-J{module_dir}",
                        "-c",
                        str(SOURCE_DIR / name),
                        "-o",
                        str(output / f"{label}.o"),
                    ]
                )
                self.assertEqual(compiled.returncode, 0, f"{name}:\n{compiled.stdout}\n{compiled.stderr}")

        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("private_data: foobar rank=1 extent=2 values=[0.0, 1.0]", oracle.stdout)
        self.assertIn("callable_or_executable_units: 0", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)

    def test_fresh_tapenade_no_root_probes_and_parser_compilation(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v320-tapenade-") as directory:
            output = Path(directory)
            for mode, flag, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run(
                    [str(TAPENADE), flag, "-O", ".", "-o", "v320", str(SOURCE_DIR / "program.f90")],
                    cwd=mode_dir,
                )
                self.assertEqual(generated.returncode, 0, f"{mode}:\n{generated.stdout}\n{generated.stderr}")
                message = mode_dir / f"v320_{suffix}.msg"
                self.assertTrue(message.is_file(), message)
                if mode == "parser":
                    parser_source = mode_dir / "v320_p.f90"
                    self.assertTrue(parser_source.is_file(), parser_source)
                    module_dir = output / "parser-mod"
                    module_dir.mkdir()
                    compiled = run(
                        [
                            os.environ.get("FC", "gfortran"),
                            *STRICT_FLAGS,
                            f"-I{SOURCE_DIR}",
                            f"-J{module_dir}",
                            "-c",
                            str(parser_source),
                            "-o",
                            str(output / "parser.o"),
                        ]
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stderr)
                else:
                    self.assertFalse((mode_dir / f"v320_{suffix}.f90").exists())
                    message_text = message.read_text(encoding="utf-8")
                    self.assertIn("No root unit to differentiate", message_text)
                    self.assertIn("The code provided does not contain a top procedure", message_text)

    def test_repaired_fortad_three_mode_no_entry_refusal(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v320-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": ["check", "--output", str(output / "parser.f90")],
                "forward": ["--mode", "forward", "--indep", "foobar", "--output", str(output / "forward.f90")],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "foobar",
                    "--dep",
                    "foobar",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertEqual(completed.returncode, 1, mode)
                self.assertIn("fortad: no function or subroutine found in source", completed.stderr, mode)
                self.assertFalse((output / f"{mode}.f90").exists(), mode)


if __name__ == "__main__":
    unittest.main(verbosity=1)
