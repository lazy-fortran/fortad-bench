#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the v544 no-entry boundary."""

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
if not (UPSTREAM / ".git").exists():
    UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
if not FORTAD_ROOT.is_dir() and Path("/mnt/storage/code/lazy-fortran/fortad").is_dir():
    FORTAD_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad")
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set07" / "v544"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
STRICT_FLAGS = [
    "-std=f2018",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-O2",
    "-fno-lto",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
]


def run(
    command: list[str], *, cwd: Path | None = None
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compile_source(
    source: Path, output: Path, module_dir: Path
) -> subprocess.CompletedProcess[str]:
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


class V544ContractTests(unittest.TestCase):
    def test_exact_sources_strict_compile_and_stored_hashes(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"],
            "expected-refusal-no-callable-procedure-module-only",
        )
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
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(sha256(source), digest, relative)
        self.assertEqual((SOURCE_DIR / "program_p.msg").read_text(encoding="utf-8"), "")

        with tempfile.TemporaryDirectory(prefix="fortad-v544-exact-") as directory:
            output = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", output / "primal.o", output / "primal-mod"
            )
            reference = compile_source(
                SOURCE_DIR / "program_p.f90",
                output / "reference.o",
                output / "reference-mod",
            )
        self.assertEqual(primal.returncode, 0, primal.stdout + primal.stderr)
        self.assertEqual(reference.returncode, 0, reference.stdout + reference.stderr)

    def test_fresh_tapenade_parser_forward_reverse_no_root_behavior(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v544-tapenade-") as directory:
            output = Path(directory)
            for mode, option, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        option,
                        "-O",
                        ".",
                        "-o",
                        "v544",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=mode_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                message = mode_dir / f"v544_{suffix}.msg"
                self.assertTrue(message.is_file(), message)
                if mode == "parser":
                    parser_source = mode_dir / "v544_p.f90"
                    self.assertTrue(parser_source.is_file(), parser_source)
                    compiled = compile_source(
                        parser_source, output / "parser.o", output / "parser-mod"
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
                    self.assertEqual(message.read_text(encoding="utf-8"), "")
                else:
                    self.assertFalse((mode_dir / f"v544_{suffix}.f90").exists())
                    message_text = message.read_text(encoding="utf-8")
                    self.assertIn("No root unit to differentiate", message_text)
                    self.assertIn("The code provided does not contain a top procedure", message_text)

    def test_fortad_refusal_and_independent_module_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v544-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": ["check", "--output", str(output / "parser.f90")],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "ptr",
                    "--name",
                    "v544_forward",
                    "--module",
                    "v544_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "ptr",
                    "--dep",
                    "ptr",
                    "--name",
                    "v544_reverse",
                    "--module",
                    "v544_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertEqual(completed.stdout, "", mode)
                self.assertEqual(
                    completed.stderr,
                    "fortad: no function or subroutine found in source\n",
                    mode,
                )
                self.assertFalse((output / f"{mode}.f90").exists(), mode)

        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("module_names: TEST", oracle.stdout)
        self.assertIn("test_parameter: C_NULL_PTR=C_PTR(0)", oracle.stdout)
        self.assertIn("callable_or_executable_units: 0", oracle.stdout)
        self.assertIn("derivative_domain: empty-no-entry-point", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
