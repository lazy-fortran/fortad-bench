#!/usr/bin/env python3
"""Exactly three behavioral contracts for the v317 no-entry boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set06" / "v317"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD_REPO = Path(os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad"))
FORTAD = FORTAD_REPO / "build" / "fo" / "bin" / "fortad"
STRICT_FLAGS = (
    "-std=f2018",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-O2",
    "-fno-lto",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
)


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class V317ContractTests(unittest.TestCase):
    def test_exact_sources_pass_strict_compilation(self) -> None:
        """Both the corpus source and stored parser reference are valid strict Fortran."""
        with tempfile.TemporaryDirectory(prefix="fortad-v317-exact-") as directory:
            scratch = Path(directory)
            for name in ("program.f90", "program_p.f90"):
                mod_dir = scratch / f"{name}-mod"
                mod_dir.mkdir()
                compiled = run(
                    [
                        "gfortran",
                        *STRICT_FLAGS,
                        "-J",
                        str(mod_dir),
                        "-c",
                        str(SOURCE_DIR / name),
                        "-o",
                        str(scratch / f"{name}.o"),
                    ]
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_fresh_tapenade_preserves_parser_and_no_root_boundaries(self) -> None:
        """Fresh pinned Tapenade emits parser output but no AD source without a root."""
        with tempfile.TemporaryDirectory(prefix="fortad-v317-tapenade-") as directory:
            scratch = Path(directory)
            for mode, option, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                output = scratch / mode
                output.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        option,
                        "-O",
                        ".",
                        "-o",
                        "v317",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=output,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                message = output / f"v317_{suffix}.msg"
                self.assertTrue(message.is_file())
                message_text = message.read_text(encoding="utf-8")
                if mode == "parser":
                    self.assertEqual(message_text, "")
                    source = output / "v317_p.f90"
                    self.assertTrue(source.is_file())
                    mod_dir = scratch / "parser-mod"
                    mod_dir.mkdir()
                    compiled = run(
                        [
                            "gfortran",
                            *STRICT_FLAGS,
                            "-J",
                            str(mod_dir),
                            "-c",
                            str(source),
                            "-o",
                            str(scratch / "parser.o"),
                        ]
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                else:
                    self.assertFalse((output / f"v317_{suffix}.f90").exists())
                    self.assertIn("No root unit to differentiate", message_text)
                    self.assertIn(
                        "The code provided does not contain a top procedure", message_text
                    )

    def test_independent_oracle_and_fortad_refuse_an_entry_point(self) -> None:
        """The source inventory is empty for AD, and repaired FortAD reports that boundary."""
        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")])
        self.assertEqual(oracle.returncode, 0, oracle.stderr)
        self.assertIn("module_count: 1", oracle.stdout)
        self.assertIn("pointer_names: p1", oracle.stdout)
        self.assertIn("callable_or_executable_units: 0", oracle.stdout)
        self.assertIn("derivative_domain: empty-no-entry-point", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)

        with tempfile.TemporaryDirectory(prefix="fortad-v317-fortad-") as directory:
            scratch = Path(directory)
            for mode_args, output_name in (
                (["check", "--proc", "m"], "parser.f90"),
                (["--mode", "forward", "--proc", "m", "--indep", "p1"], "forward.f90"),
                (["--mode", "reverse", "--proc", "m", "--indep", "p1", "--dep", "p1"], "reverse.f90"),
            ):
                output = scratch / output_name
                refused = run(
                    [
                        str(FORTAD),
                        *mode_args,
                        "--output",
                        str(output),
                        str(SOURCE_DIR / "program.f90"),
                    ]
                )
                self.assertNotEqual(refused.returncode, 0, mode_args)
                self.assertIn(
                    "fortad: no procedure named 'm' in this source",
                    refused.stdout + refused.stderr,
                )
                self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
