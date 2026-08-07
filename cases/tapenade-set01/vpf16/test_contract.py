#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned vpf16 boundary."""

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
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set11" / "vpf16"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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


class Vpf16ContractTests(unittest.TestCase):
    def test_exact_sources_options_and_stored_reference_compile(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-module-only-no-entry")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(manifest["fortad_revision"], "3a946d34d3caa7a75fb6f891139023650b4ce51a")
        self.assertEqual(manifest["selected_entry_points"], [])
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["upstream_revision"],
        )
        self.assertEqual(
            run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["fortad_revision"],
        )
        for relative, digest in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(UPSTREAM / relative), digest, relative)
        self.assertEqual(
            (SOURCE_DIR / "Options").read_text(encoding="utf-8").strip(),
            "-msginfile -noinclude -noisize",
        )
        self.assertEqual(manifest["options"], ["-msginfile -noinclude -noisize"])

        with tempfile.TemporaryDirectory(prefix="fortad-vpf16-exact-") as directory:
            output = Path(directory)
            for name in ("program.f90", "program_p.f90"):
                compiled = compile_source(
                    SOURCE_DIR / name,
                    output / f"{name}.o",
                    output / f"{name}-mod",
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_fresh_tapenade_parser_and_no_root_modes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-vpf16-tapenade-") as directory:
            output = Path(directory)
            for mode, option, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                generated_dir = output / mode
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        option,
                        "-O",
                        str(generated_dir),
                        "-o",
                        "vpf16",
                        "program.f90",
                    ],
                    cwd=SOURCE_DIR,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                message = generated_dir / f"vpf16_{suffix}.msg"
                self.assertTrue(message.is_file(), message)
                message_text = message.read_text(encoding="utf-8")
                if mode == "parser":
                    self.assertEqual(message_text, "")
                    parser_source = generated_dir / "vpf16_p.f90"
                    self.assertTrue(parser_source.is_file(), parser_source)
                    compiled = compile_source(
                        parser_source, output / "parser.o", output / "parser-mod"
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                else:
                    self.assertFalse((generated_dir / f"vpf16_{suffix}.f90").exists())
                    self.assertIn("No root unit to differentiate", message_text)
                    self.assertIn(
                        "The code provided does not contain a top procedure", message_text
                    )

    def test_independent_oracle_and_fortad_three_mode_no_entry_refusal(self) -> None:
        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_modules: ESMF_CalendarMod,mo", oracle.stdout)
        self.assertIn("oracle_entry_points: none", oracle.stdout)
        self.assertIn("derivative_domain: empty-no-entry-point", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)

        with tempfile.TemporaryDirectory(prefix="fortad-vpf16-fortad-") as directory:
            output = Path(directory)
            requests = (
                ("parser", ["check", "--output", str(output / "parser.f90")]),
                (
                    "forward",
                    [
                        "--mode",
                        "forward",
                        "--proc",
                        "esmf_calendarmod",
                        "--indep",
                        "esmf_calendar_dummy",
                        "--name",
                        "vpf16_forward",
                        "--module",
                        "vpf16_forward_mod",
                        "--output",
                        str(output / "forward.f90"),
                    ],
                ),
                (
                    "reverse",
                    [
                        "--mode",
                        "reverse",
                        "--proc",
                        "esmf_calendarmod",
                        "--indep",
                        "esmf_calendar_dummy",
                        "--dep",
                        "esmf_calendar_dummy",
                        "--name",
                        "vpf16_reverse",
                        "--module",
                        "vpf16_reverse_mod",
                        "--output",
                        str(output / "reverse.f90"),
                    ],
                ),
            )
            for mode, arguments in requests:
                refused = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertEqual(refused.returncode, 1, mode)
                self.assertEqual(refused.stdout, "", mode)
                if mode == "parser":
                    self.assertEqual(
                        refused.stderr,
                        "fortad: no function or subroutine found in source\n",
                        mode,
                    )
                else:
                    self.assertEqual(
                        refused.stderr,
                        "fortad: no procedure named 'esmf_calendarmod' in this source\n",
                        mode,
                    )
                self.assertFalse((output / f"{mode}.f90").exists(), mode)


if __name__ == "__main__":
    unittest.main(verbosity=1)
