#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v505 boundary."""

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
if not DEFAULT_UPSTREAM.is_dir():
    DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v505"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
MANIFEST = CASE / "manifest.toml"
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


class V505ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_reference_strict_compile(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"], "expected-refusal-without-bounded-port"
        )
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(
            run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"]).stdout.strip(),
            manifest["upstream_revision"],
        )
        self.assertTrue((SOURCE_DIR / "program.f90").is_file())
        self.assertTrue((SOURCE_DIR / "program_d.f90").is_file())
        self.assertTrue((SOURCE_DIR / "program_d.msg").is_file())
        for name in ("program_p.f90", "program_p.msg", "program_b.f90", "program_b.msg"):
            self.assertFalse((SOURCE_DIR / name).exists(), name)
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

        with tempfile.TemporaryDirectory(prefix="fortad-v505-exact-") as directory:
            output = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", output / "program.o", output / "primal-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_d.f90", output / "program_d.o", output / "stored-mod"
            )
        self.assertEqual(primal.returncode, 0, primal.stderr)
        self.assertEqual(stored.returncode, 0, stored.stderr)
        self.assertIn("ftest", primal.stderr)
        self.assertIn("ftest_d", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compile(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v505-tapenade-") as directory:
            output = Path(directory)
            for mode, flag, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        flag,
                        "-root",
                        "top",
                        "-O",
                        ".",
                        "-o",
                        "v505",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=mode_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                source = mode_dir / f"v505_{suffix}.f90"
                message = mode_dir / f"v505_{suffix}.msg"
                self.assertTrue(source.is_file(), source)
                self.assertTrue(message.is_file(), message)
                compiled = compile_source(
                    source, output / f"{mode}.o", output / f"{mode}-mod"
                )
                self.assertEqual(compiled.returncode, 0, compiled.stderr)
            self.assertIn("External routine ftest", (output / "parser" / "v505_p.msg").read_text())
            for mode in ("forward", "reverse"):
                suffix = "d" if mode == "forward" else "b"
                self.assertIn(
                    "Please provide a differential of function ftest",
                    (output / mode / f"v505_{suffix}.msg").read_text(),
                )

    def test_exact_fortad_refusals_and_independent_semantic_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v505-fortad-") as directory:
            output = Path(directory)
            requests = {
                "parser": [
                    "check",
                    "--proc",
                    "top",
                    "--output",
                    str(output / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--indep",
                    "r,s",
                    "--dep",
                    "top",
                    "--proc",
                    "top",
                    "--name",
                    "v505_forward",
                    "--module",
                    "v505_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--indep",
                    "r,s",
                    "--dep",
                    "top",
                    "--proc",
                    "top",
                    "--name",
                    "v505_reverse",
                    "--module",
                    "v505_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in requests.items():
                completed = run([str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")])
                diagnostic = completed.stdout + completed.stderr
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn("unsupported statement at line 12", diagnostic, mode)
                self.assertFalse((output / f"{mode}.f90").exists())

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_call_graph: top -> external ftest(r,s,compute)", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
