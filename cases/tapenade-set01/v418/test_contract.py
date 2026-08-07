#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v418 MPI boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
DEFAULT_UPSTREAM = CASE.parents[2] / "upstream" / "tapenade"
if not DEFAULT_UPSTREAM.is_dir():
    DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
FORTAD_REPO = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v418"
FORTAD = FORTAD_REPO / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "mpifort")
FLAGS = [
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


def compile_source(source: Path, output: Path, module_dir: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    return run(
        [FC, *FLAGS, f"-I{SOURCE_DIR}", *extra, f"-J{module_dir}", "-c", str(source), "-o", str(output)]
    )


class V418ContractTests(unittest.TestCase):
    def test_exact_references_preserve_compiler_boundaries(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a")
        for relative, expected in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(UPSTREAM / relative), expected, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v418-exact-") as directory:
            output = Path(directory)
            primal = compile_source(SOURCE_DIR / "program.f90", output / "primal.o", output / "primal-mod")
            stored = compile_source(SOURCE_DIR / "program_Rd.f90", output / "stored.o", output / "rd-mod")
            driver = compile_source(
                SOURCE_DIR / "topd.f90",
                output / "driver.o",
                output / "driver-mod",
                f"-I{output / 'rd-mod'}",
            )
        self.assertNotEqual(primal.returncode, 0)
        self.assertIn("More actual than formal arguments", primal.stderr)
        self.assertIn("Rank mismatch in argument", primal.stderr)
        self.assertEqual(stored.returncode, 0, stored.stdout + stored.stderr)
        self.assertNotEqual(driver.returncode, 0)
        self.assertIn("real4rdtype", driver.stderr)

    def test_fresh_tapenade_generation_and_strict_compile(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-v418-fresh-") as directory:
            output = Path(directory)
            support_mod = output / "support-mod"
            support = compile_source(
                UPSTREAM / "ADFirstAidKit" / "adMPI.f90",
                output / "admpi.o",
                support_mod,
                f"-I{UPSTREAM / 'ADFirstAidKit'}",
            )
            self.assertEqual(support.returncode, 0, support.stdout + support.stderr)
            for mode, tap_mode, suffix in (("parser", "-p", "p"), ("tangent", "-d", "d"), ("reverse", "-b", "b")):
                generated_dir = output / mode
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        "-association",
                        "byaddress",
                        tap_mode,
                        "-root",
                        "msg1",
                        "-root",
                        "msg2",
                        "-O",
                        ".",
                        "-o",
                        "v418",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = generated_dir / f"v418_{suffix}.f90"
                self.assertTrue(source.is_file())
                extra = () if mode == "parser" else (f"-I{support_mod}",)
                compiled = compile_source(source, output / f"{mode}.o", output / f"{mode}-mod", *extra)
                if mode == "parser":
                    self.assertNotEqual(compiled.returncode, 0)
                    self.assertIn("More actual than formal arguments", compiled.stderr)
                else:
                    self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_exact_fortad_behavior_and_independent_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v418-engine-") as directory:
            output = Path(directory)
            for root, parser_compile_status in (("msg1", 0), ("msg2", 1)):
                parser_output = output / f"{root}-parser.f90"
                parsed = run(
                    [str(FORTAD), "check", "--proc", root, "--output", str(parser_output), str(SOURCE_DIR / "program.f90")]
                )
                self.assertEqual(parsed.returncode, 0, root)
                self.assertTrue(parser_output.is_file())
                compiled = compile_source(parser_output, output / f"{root}-parser.o", output / f"{root}-mod")
                self.assertEqual(compiled.returncode, parser_compile_status, root)
                if root == "msg2":
                    self.assertIn("More actual than formal arguments", compiled.stderr)

                forward = run(
                    [
                        str(FORTAD),
                        "--mode",
                        "forward",
                        "--indep",
                        "val1",
                        "--dep",
                        "val2",
                        "--proc",
                        root,
                        "--name",
                        f"v418_{root}_forward",
                        "--module",
                        f"v418_{root}_forward_mod",
                        "--output",
                        str(output / f"{root}-forward.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ]
                )
                reverse = run(
                    [
                        str(FORTAD),
                        "--mode",
                        "reverse",
                        "--indep",
                        "val1",
                        "--dep",
                        "val2",
                        "--proc",
                        root,
                        "--name",
                        f"v418_{root}_reverse",
                        "--module",
                        f"v418_{root}_reverse_mod",
                        "--output",
                        str(output / f"{root}-reverse.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ]
                )
                self.assertNotEqual(forward.returncode, 0, root)
                self.assertNotEqual(reverse.returncode, 0, root)
                self.assertIn(
                    "MPI_ISEND" if root == "msg1" else "MPI_RECV",
                    forward.stderr,
                )
                self.assertIn(
                    "MPI_ISEND" if root == "msg1" else "MPI_RECV",
                    reverse.stderr,
                )
                self.assertFalse((output / f"{root}-forward.f90").exists())
                self.assertFalse((output / f"{root}-reverse.f90").exists())

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("finite_difference_max_error:", oracle.stdout)
        self.assertIn("adjoint_identity_residual:", oracle.stdout)
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        self.assertIn("classification: expected-refusal-invalid-upstream", report)
        self.assertIn("port_result: not-applicable-no-standard-conforming-exact-candidate", report)


if __name__ == "__main__":
    unittest.main(verbosity=1)
