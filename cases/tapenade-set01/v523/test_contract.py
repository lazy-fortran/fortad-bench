#!/usr/bin/env python3
"""Exactly three behavioral contracts for the v523 empty-source boundary."""

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
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad")
)
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set07" / "v523"
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
TAPENADE_REVISION = "e59864cab441d4175df75383b3ff58c3dcd26df9"
FORTAD_REVISION = "3a946d34d3caa7a75fb6f891139023650b4ce51a"


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
            "-c",
            str(source),
            "-J",
            str(module_dir),
            "-o",
            str(output),
        ]
    )


class V523ContractTests(unittest.TestCase):
    def test_exact_empty_source_and_stored_reference_boundary(self) -> None:
        """The exact source is valid empty Fortran; the stored reference is metadata only."""
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"], "expected-refusal-empty-source-no-entry-point"
        )
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            TAPENADE_REVISION,
        )
        self.assertEqual(
            run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]).stdout.strip(),
            FORTAD_REVISION,
        )
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(sha256(source), digest, relative)
        self.assertEqual((SOURCE_DIR / "program.f90").read_bytes(), b"")
        self.assertEqual((SOURCE_DIR / "program_p.msg").read_bytes(), b"")
        self.assertFalse((SOURCE_DIR / "program_p.f90").exists())
        with tempfile.TemporaryDirectory(prefix="fortad-v523-exact-") as directory:
            compiled = compile_source(
                SOURCE_DIR / "program.f90",
                Path(directory) / "program.o",
                Path(directory) / "modules",
            )
        self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
        self.assertEqual(compiled.stdout + compiled.stderr, "")

    def test_fresh_tapenade_parser_forward_reverse_no_root_probes(self) -> None:
        """Fresh Tapenade distinguishes an empty parser message from no-root AD messages."""
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v523-tapenade-") as directory:
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
                        ".",
                        "-o",
                        "v523",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                message = generated_dir / f"v523_{suffix}.msg"
                self.assertTrue(message.is_file())
                message_text = message.read_text(encoding="utf-8")
                self.assertFalse((generated_dir / f"v523_{suffix}.f90").exists())
                if mode == "parser":
                    self.assertEqual(message_text, "")
                else:
                    self.assertIn("No root unit to differentiate", message_text)
                    self.assertIn(
                        "The code provided does not contain a top procedure", message_text
                    )

    def test_independent_empty_oracle_and_fortad_three_mode_no_entry_refusal(self) -> None:
        """The independent zero-unit oracle agrees with FortAD's exact no-entry refusal."""
        oracle = run(
            ["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")]
        )
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("callable_units: 0", oracle.stdout)
        self.assertIn("executable_statements: 0", oracle.stdout)
        self.assertIn("derivative_domain: empty-no-entry-point", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)

        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v523-fortad-") as directory:
            output = Path(directory)
            requests = (
                (
                    "parser",
                    [
                        str(FORTAD),
                        "check",
                        "--output",
                        str(output / "parser.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
                (
                    "forward",
                    [
                        str(FORTAD),
                        str(SOURCE_DIR / "program.f90"),
                        "--mode",
                        "forward",
                        "--indep",
                        "p1",
                        "--output",
                        str(output / "forward.f90"),
                    ],
                ),
                (
                    "reverse",
                    [
                        str(FORTAD),
                        "--mode",
                        "reverse",
                        "--indep",
                        "p1",
                        "--dep",
                        "p2",
                        "--output",
                        str(output / "reverse.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                ),
            )
            for label, command in requests:
                refused = run(command)
                self.assertNotEqual(refused.returncode, 0, label)
                self.assertIn(
                    "no function or subroutine found in source",
                    (refused.stdout + refused.stderr).lower(),
                    label,
                )
                self.assertFalse((output / f"{label}.f90").exists(), label)


if __name__ == "__main__":
    unittest.main(verbosity=1)
