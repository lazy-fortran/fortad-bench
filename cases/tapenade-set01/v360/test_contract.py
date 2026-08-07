#!/usr/bin/env python3
"""Exactly three behavioral contracts for the v360 no-entry boundary."""

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
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad")
)
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set06" / "v360"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class V360ContractTests(unittest.TestCase):
    def test_exact_sources_compile_and_match_pinned_references(self) -> None:
        """The exact source and stored parser reference retain their compiler behavior."""
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-no-callable-procedure-module-only",
        )
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "3a946d34d3caa7a75fb6f891139023650b4ce51a",
        )
        self.assertEqual(manifest["selected_entry_points"], [])
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["upstream_revision"],
        )
        for relative, digest in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(UPSTREAM / relative), digest, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v360-exact-") as directory:
            scratch = Path(directory)
            for label, name in (("primal", "program.f90"), ("reference", "program_p.f90")):
                module_dir = scratch / f"{label}-mod"
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
                        str(scratch / f"{label}.o"),
                    ]
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                self.assertIn("Unused PRIVATE module variable", compiled.stderr)
                self.assertIn("gm_show", compiled.stderr)
                self.assertIn("gm_unit", compiled.stderr)

    def test_fresh_tapenade_preserves_parser_and_no_root_boundaries(self) -> None:
        """Fresh pinned Tapenade separates parser output from no-root AD modes."""
        with tempfile.TemporaryDirectory(prefix="fortad-v360-tapenade-") as directory:
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
                        "v360",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=output,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                message = output / f"v360_{suffix}.msg"
                self.assertTrue(message.is_file(), message)
                message_text = message.read_text(encoding="utf-8")
                if mode == "parser":
                    self.assertEqual(message_text, "")
                    parser_source = output / "v360_p.f90"
                    self.assertTrue(parser_source.is_file(), parser_source)
                    parser_mod = scratch / "parser-mod"
                    parser_mod.mkdir()
                    compiled = run(
                        [
                            os.environ.get("FC", "gfortran"),
                            *STRICT_FLAGS,
                            f"-I{SOURCE_DIR}",
                            f"-J{parser_mod}",
                            "-c",
                            str(parser_source),
                            "-o",
                            str(scratch / "parser.o"),
                        ]
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                    self.assertIn("Unused PRIVATE module variable", compiled.stderr)
                else:
                    self.assertFalse((output / f"v360_{suffix}.f90").exists())
                    self.assertIn("No root unit to differentiate", message_text)
                    self.assertIn("The code provided does not contain a top procedure", message_text)

    def test_independent_oracle_and_fortad_refuse_an_entry_point(self) -> None:
        """Source semantics and the repaired FortAD CLI both expose an empty AD domain."""
        self.assertEqual(
            run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"]).stdout.strip(),
            "3a946d34d3caa7a75fb6f891139023650b4ce51a",
        )
        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("module_count: 2", oracle.stdout)
        self.assertIn("module_use: M1 USE M0", oracle.stdout)
        self.assertIn("callable_or_executable_units: 0", oracle.stdout)
        self.assertIn("derivative_domain: empty-no-entry-point", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)

        with tempfile.TemporaryDirectory(prefix="fortad-v360-fortad-") as directory:
            scratch = Path(directory)
            requests = (
                (
                    "parser",
                    [
                        "check",
                        "--proc",
                        "m0",
                        "--output",
                        str(scratch / "parser.f90"),
                    ],
                ),
                (
                    "forward",
                    [
                        "--mode",
                        "forward",
                        "--proc",
                        "m0",
                        "--indep",
                        "m0_i",
                        "--name",
                        "v360_forward",
                        "--module",
                        "v360_forward_mod",
                        "--output",
                        str(scratch / "forward.f90"),
                    ],
                ),
                (
                    "reverse",
                    [
                        "--mode",
                        "reverse",
                        "--proc",
                        "m0",
                        "--indep",
                        "m0_i",
                        "--dep",
                        "m0_i",
                        "--name",
                        "v360_reverse",
                        "--module",
                        "v360_reverse_mod",
                        "--output",
                        str(scratch / "reverse.f90"),
                    ],
                ),
            )
            for label, arguments in requests:
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertNotEqual(completed.returncode, 0, label)
                self.assertEqual(completed.stdout, "", label)
                self.assertEqual(
                    completed.stderr,
                    "fortad: no procedure named 'm0' in this source\n",
                    label,
                )
                self.assertFalse((scratch / f"{label}.f90").exists(), label)


if __name__ == "__main__":
    unittest.main(verbosity=1)
