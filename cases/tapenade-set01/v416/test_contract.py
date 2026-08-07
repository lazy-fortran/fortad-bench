#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v416 case."""

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
FORTAD_REPO = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v416"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD = FORTAD_REPO / "build" / "fo" / "bin" / "fortad"
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


def compile_source(source: Path, output: Path, module_dir: Path) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    return run(
        [
            os.environ.get("FC", "gfortran"),
            *FLAGS,
            f"-I{SOURCE_DIR}",
            f"-I{module_dir}",
            f"-J{module_dir}",
            "-c",
            str(source),
            "-o",
            str(output),
        ]
    )


def fortad(*arguments: str) -> subprocess.CompletedProcess[str]:
    return run(["fo", "exec", "--no-build", "fortad", *arguments], cwd=FORTAD_REPO)


class V416ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_reference_compile_boundary(self) -> None:
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
        for name, expected in manifest["upstream_sha256"].items():
            self.assertEqual(hashlib.sha256((SOURCE_DIR / name).read_bytes()).hexdigest(), expected)

        with tempfile.TemporaryDirectory(prefix="fortad-v416-exact-") as directory:
            scratch = Path(directory)
            primal = compile_source(SOURCE_DIR / "program.f90", scratch / "primal.o", scratch / "primal-mod")
            stored = compile_source(
                SOURCE_DIR / "program_Rd.f90", scratch / "stored.o", scratch / "stored-mod"
            )
        self.assertNotEqual(primal.returncode, 0)
        self.assertRegex(primal.stderr, r"used before it is typed|GNU Extension.*nm_ha")
        self.assertEqual(stored.returncode, 0, stored.stdout + stored.stderr)
        self.assertIn("Integer division truncated", stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compilation(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v416-tapenade-") as directory:
            scratch = Path(directory)
            for mode, option, suffix in (("parser", "-p", "p"), ("forward", "-d", "d"), ("reverse", "-b", "b")):
                output = scratch / mode
                output.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        option,
                        "-root",
                        "precechcin",
                        "-O",
                        ".",
                        "-o",
                        "v416",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=output,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"v416_{suffix}.f90"
                self.assertTrue(source.is_file(), source)
                self.assertTrue((output / f"v416_{suffix}.msg").is_file())
                compiled = compile_source(source, scratch / f"{mode}.o", scratch / f"{mode}-mod")
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_exact_fortad_and_bounded_port_behavior(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v416-engine-") as directory:
            scratch = Path(directory)
            exact_requests = (
                (
                    "parser",
                    [
                        "check",
                        "--proc",
                        "precechcin",
                        "--output",
                        str(scratch / "parser.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    False,
                ),
                (
                    "forward",
                    [
                        "--mode",
                        "forward",
                        "--proc",
                        "precechcin",
                        "--indep",
                        "x,Tm_ha",
                        "--name",
                        "v416_forward",
                        "--module",
                        "v416_forward_mod",
                        "--output",
                        str(scratch / "forward.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    True,
                ),
                (
                    "reverse",
                    [
                        "--mode",
                        "reverse",
                        "--proc",
                        "precechcin",
                        "--indep",
                        "x,Tm_ha",
                        "--dep",
                        "y",
                        "--name",
                        "v416_reverse",
                        "--module",
                        "v416_reverse_mod",
                        "--output",
                        str(scratch / "reverse.f90"),
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    True,
                ),
            )
            for mode, arguments, compiles in exact_requests:
                transformed = fortad(*arguments)
                self.assertEqual(transformed.returncode, 0, mode + transformed.stderr)
                output = scratch / f"{mode}.f90"
                self.assertTrue(output.is_file())
                compiled = compile_source(output, scratch / f"{mode}.o", scratch / f"{mode}-mod")
                if compiles:
                    self.assertEqual(compiled.returncode, 0, mode + compiled.stderr)
                else:
                    self.assertNotEqual(compiled.returncode, 0)
                    self.assertRegex(compiled.stderr, r"used before it is typed|GNU Extension.*nm_ha")

            forward = scratch / "port-forward.f90"
            reverse = scratch / "port-reverse.f90"
            generated_forward = fortad(
                "--mode",
                "forward",
                "--proc",
                "set01_v416",
                "--indep",
                "x,Tm_ha",
                "--name",
                "v416_port_forward",
                "--module",
                "v416_port_forward_mod",
                "--output",
                str(forward),
                str(CASE / "port.f90"),
            )
            generated_reverse = fortad(
                "--mode",
                "reverse",
                "--proc",
                "set01_v416",
                "--indep",
                "x,Tm_ha",
                "--dep",
                "y",
                "--name",
                "v416_port_reverse",
                "--module",
                "v416_port_reverse_mod",
                "--output",
                str(reverse),
                str(CASE / "port.f90"),
            )
            self.assertEqual(generated_forward.returncode, 0, generated_forward.stderr)
            self.assertEqual(generated_reverse.returncode, 0, generated_reverse.stderr)
            module_dir = scratch / "port-mod"
            port = compile_source(CASE / "port.f90", scratch / "port.o", module_dir)
            forward_compiled = compile_source(forward, scratch / "port-forward.o", module_dir)
            reverse_compiled = compile_source(reverse, scratch / "port-reverse.o", module_dir)
            harness = compile_source(CASE / "harness.f90", scratch / "harness.o", module_dir)
            for compiled in (port, forward_compiled, reverse_compiled, harness):
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            linked = run(
                [
                    os.environ.get("FC", "gfortran"),
                    "-o",
                    str(scratch / "harness"),
                    str(scratch / "port.o"),
                    str(scratch / "port-forward.o"),
                    str(scratch / "port-reverse.o"),
                    str(scratch / "harness.o"),
                ]
            )
            self.assertEqual(linked.returncode, 0, linked.stdout + linked.stderr)
            executed = run([str(scratch / "harness")])
            self.assertEqual(executed.returncode, 0, executed.stdout + executed.stderr)
            self.assertIn("harness_status: pass", executed.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
