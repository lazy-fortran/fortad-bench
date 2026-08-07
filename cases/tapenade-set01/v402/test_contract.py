#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v402 refusal boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM_CANDIDATE = Path(
    "/mnt/storage/code/lazy-fortran/fortad-bench/upstreams/tapenade-e59864c"
)
if not UPSTREAM_CANDIDATE.is_dir():
    UPSTREAM_CANDIDATE = Path(
        "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"
    )
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(UPSTREAM_CANDIDATE)))
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")
)
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v402"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
STRICT_FLAGS = (
    "-std=f2018",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-cpp",
)


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class V402ContractTests(unittest.TestCase):
    def test_exact_upstream_strict_compile_behavior(self) -> None:
        """The two exact corpus sources preserve their independent refusals."""
        revision = run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"])
        self.assertEqual(
            revision.stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
            revision.stderr,
        )
        with tempfile.TemporaryDirectory(prefix="fortad-v402-exact-") as directory:
            scratch = Path(directory)
            primal = run(
                [
                    "gfortran",
                    *STRICT_FLAGS,
                    f"-I{SOURCE_DIR}",
                    f"-J{scratch / 'primal-mod'}",
                    "-c",
                    str(SOURCE_DIR / "program.f90"),
                    "-o",
                    str(scratch / "program.o"),
                ]
            )
            reverse = run(
                [
                    "gfortran",
                    *STRICT_FLAGS,
                    f"-I{SOURCE_DIR}",
                    f"-J{scratch / 'reverse-mod'}",
                    "-c",
                    str(SOURCE_DIR / "program_b.f90"),
                    "-o",
                    str(scratch / "program_b.o"),
                ]
            )
        self.assertNotEqual(primal.returncode, 0)
        self.assertIn("Nonstandard type declaration REAL*8", primal.stderr)
        self.assertNotEqual(reverse.returncode, 0)
        # Diagnostic order is compiler-version dependent: strict gfortran may
        # report REAL*8 before it reaches the absent module.  The independent
        # oracle below checks the missing DIFFSIZES obligation directly.
        self.assertTrue(
            "diffsizes.mod" in reverse.stderr
            or "Nonstandard type declaration REAL*8" in reverse.stderr,
            reverse.stderr,
        )
        self.assertFalse((SOURCE_DIR / "diffsizes.f90").exists())
        self.assertFalse((SOURCE_DIR / "DIFFSIZES.f90").exists())

    def test_fresh_tapenade_generation_and_strict_compile_behavior(self) -> None:
        """Fresh pinned outputs exist, but strict compilation preserves refusal."""
        with tempfile.TemporaryDirectory(prefix="fortad-v402-tapenade-") as directory:
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
                        "-root",
                        "timeloop",
                        "-O",
                        ".",
                        "-o",
                        "v402",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=output,
                )
                self.assertEqual(
                    generated.returncode,
                    0,
                    f"{mode}:\n{generated.stdout}\n{generated.stderr}",
                )
                source = output / f"v402_{suffix}.f90"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((output / f"v402_{suffix}.msg").is_file())
                compiled = run(
                    [
                        "gfortran",
                        *STRICT_FLAGS,
                        f"-I{SOURCE_DIR}",
                        f"-J{scratch / (mode + '-mod')}",
                        "-c",
                        str(source),
                        "-o",
                        str(scratch / f"{mode}.o"),
                    ]
                )
                self.assertNotEqual(compiled.returncode, 0)
                self.assertIn("Nonstandard type declaration REAL*8", compiled.stderr)

    def test_exact_fortad_parser_forward_reverse_behavior(self) -> None:
        """FortAD refuses all exact modes at active allocatable state."""
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v402-exact-engine-") as directory:
            scratch = Path(directory)
            commands = {
                "parser": [
                    str(FORTAD),
                    "check",
                    "--proc",
                    "timeloop",
                    "--output",
                    str(scratch / "parser.f90"),
                ],
                "forward": [
                    str(FORTAD),
                    "--mode",
                    "forward",
                    "--proc",
                    "timeloop",
                    "--indep",
                    "k",
                    "--name",
                    "v402_forward",
                    "--module",
                    "v402_forward_mod",
                    "--output",
                    str(scratch / "forward.f90"),
                ],
                "reverse": [
                    str(FORTAD),
                    "--mode",
                    "reverse",
                    "--proc",
                    "timeloop",
                    "--indep",
                    "k",
                    "--dep",
                    "a",
                    "--name",
                    "v402_reverse",
                    "--module",
                    "v402_reverse_mod",
                    "--output",
                    str(scratch / "reverse.f90"),
                ],
            }
            for mode, command in commands.items():
                completed = run(command + [str(SOURCE_DIR / "program.f90")])
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn(
                    "unsupported allocation lifetime construct 'allocatable declaration/component' at line 12",
                    completed.stderr,
                )
                self.assertFalse((scratch / f"{mode}.f90").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
