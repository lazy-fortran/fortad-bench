#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v504 case."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = Path(
    os.environ.get(
        "TAPENADE_REPO", "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"
    )
)
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v504"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FLAGS = (
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


def compile_source(
    source: Path,
    output: Path,
    module_dir: Path,
    *include_dirs: Path,
) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    command = [os.environ.get("FC", "gfortran"), *FLAGS, f"-I{SOURCE_DIR}"]
    command.extend(f"-I{directory}" for directory in include_dirs)
    command.extend((f"-I{module_dir}", f"-J{module_dir}", "-c", str(source), "-o", str(output)))
    return run(command)


def fortad(*arguments: str) -> subprocess.CompletedProcess[str]:
    return run(["fo", "exec", "--no-build", "fortad", *arguments], cwd=FORTAD_ROOT)


class V504ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_reference_strict_refusal(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "runnable-ported-with-exact-source-refusal")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        revision = run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"])
        self.assertEqual(revision.stdout.strip(), manifest["upstream_revision"], revision.stderr)
        for relative, expected in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), expected)
        for name in ("program_b.f90", "program_b.msg"):
            self.assertFalse((SOURCE_DIR / name).exists(), name)

        with tempfile.TemporaryDirectory(prefix="fortad-v504-exact-") as directory:
            scratch = Path(directory)
            primal = compile_source(
                SOURCE_DIR / "program.f90", scratch / "primal.o", scratch / "primal-mod"
            )
            stored = compile_source(
                SOURCE_DIR / "program_d.f90", scratch / "stored.o", scratch / "stored-mod"
            )
        self.assertNotEqual(primal.returncode, 0)
        self.assertNotEqual(stored.returncode, 0)
        self.assertIn("ambiguous reference to", primal.stderr)
        self.assertIn("ambiguous reference to", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_refusal(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v504-tapenade-") as directory:
            scratch = Path(directory)
            for mode, option, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                generated_dir = scratch / mode
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        option,
                        "-root",
                        "top",
                        "-O",
                        ".",
                        "-o",
                        "v504",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                source = generated_dir / f"v504_{suffix}.f90"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((generated_dir / f"v504_{suffix}.msg").is_file())
                compiled = compile_source(
                    source, scratch / f"{mode}.o", scratch / f"{mode}-mod"
                )
                self.assertNotEqual(compiled.returncode, 0, mode)
                diagnostic = compiled.stdout + compiled.stderr
                self.assertRegex(
                    diagnostic,
                    r"has no IMPLICIT type|ambiguous reference to|Cannot open module file",
                )

    def test_exact_fortad_port_and_independent_oracle(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-v504-engine-") as directory:
            scratch = Path(directory)
            exact_requests = {
                "parser": [
                    "check",
                    "--proc",
                    "top",
                    "--output",
                    str(scratch / "exact-parser.f90"),
                    str(SOURCE_DIR / "program.f90"),
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
                    "v504_exact_forward",
                    "--module",
                    "v504_exact_forward_mod",
                    "--output",
                    str(scratch / "exact-forward.f90"),
                    str(SOURCE_DIR / "program.f90"),
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
                    "v504_exact_reverse",
                    "--module",
                    "v504_exact_reverse_mod",
                    "--output",
                    str(scratch / "exact-reverse.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
            }
            for mode, arguments in exact_requests.items():
                transformed = fortad(*arguments)
                self.assertNotEqual(transformed.returncode, 0, mode)
                self.assertIn("unsupported statement at line 62", transformed.stderr)
                self.assertFalse((scratch / f"exact-{mode}.f90").exists())

            forward = scratch / "port-forward.f90"
            reverse = scratch / "port-reverse.f90"
            generated_forward = fortad(
                "--mode",
                "forward",
                "--indep",
                "r,s",
                "--dep",
                "top",
                "--proc",
                "set01_v504",
                "--name",
                "v504_port_forward",
                "--module",
                "v504_port_forward_mod",
                "--output",
                str(forward),
                str(CASE / "port.f90"),
            )
            generated_reverse = fortad(
                "--mode",
                "reverse",
                "--indep",
                "r,s",
                "--dep",
                "top",
                "--proc",
                "set01_v504",
                "--name",
                "v504_port_reverse",
                "--module",
                "v504_port_reverse_mod",
                "--output",
                str(reverse),
                str(CASE / "port.f90"),
            )
            self.assertEqual(generated_forward.returncode, 0, generated_forward.stderr)
            self.assertEqual(generated_reverse.returncode, 0, generated_reverse.stderr)

            port_mod = scratch / "port-mod"
            forward_mod = scratch / "forward-mod"
            reverse_mod = scratch / "reverse-mod"
            port = compile_source(CASE / "port.f90", scratch / "port.o", port_mod)
            forward_compiled = compile_source(forward, scratch / "forward.o", forward_mod)
            reverse_compiled = compile_source(reverse, scratch / "reverse.o", reverse_mod)
            harness = compile_source(
                CASE / "harness.f90",
                scratch / "harness.o",
                scratch / "harness-mod",
                forward_mod,
                reverse_mod,
            )
            for compiled in (port, forward_compiled, reverse_compiled, harness):
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            linked = run(
                [
                    os.environ.get("FC", "gfortran"),
                    "-o",
                    str(scratch / "harness"),
                    str(scratch / "port.o"),
                    str(scratch / "forward.o"),
                    str(scratch / "reverse.o"),
                    str(scratch / "harness.o"),
                ]
            )
            self.assertEqual(linked.returncode, 0, linked.stdout + linked.stderr)
            executed = run([str(scratch / "harness")])
            self.assertEqual(executed.returncode, 0, executed.stdout + executed.stderr)
            self.assertIn("harness_status: pass", executed.stdout)

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
