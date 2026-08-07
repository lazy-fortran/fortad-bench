#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v526 boundary and port."""

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
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v526"
FORTAD = FORTAD_REPO / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FC = os.environ.get("FC", "gfortran")
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


def compile_source(
    source: Path, output: Path, module_dir: Path
) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    return run(
        [
            FC,
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


class V526ContractTests(unittest.TestCase):
    def test_exact_source_and_stored_module_consumer_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["classification"], "expected-refusal-with-bounded-sing3-port"
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
        for relative, expected in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), expected)

        with tempfile.TemporaryDirectory(prefix="fortad-v526-exact-") as directory:
            output = Path(directory)
            exact = compile_source(
                SOURCE_DIR / "program.f90", output / "program.o", output / "exact-mod"
            )
            stored = compile_source(
                CASE / "stored_modules_probe.f90",
                output / "stored-modules.o",
                output / "stored-mod",
            )
        self.assertNotEqual(exact.returncode, 0, exact.stdout + exact.stderr)
        for marker in ("Parameter", "Ambiguous interfaces", "REAL*8", "fox_dom.mod"):
            self.assertIn(marker, exact.stderr)
        self.assertEqual(stored.returncode, 0, stored.stdout + stored.stderr)

    def test_fresh_tapenade_generation_and_strict_compile_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v526-fresh-") as directory:
            output = Path(directory)
            expected_compile_markers = {
                "p": "no IMPLICIT type",
                "d": "fox_dom.mod",
                "b": "fox_dom.mod",
            }
            for mode, suffix in (("p", "parser"), ("d", "tangent"), ("b", "reverse")):
                generated_dir = output / suffix
                generated_dir.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        f"-{mode}",
                        "-root",
                        "SING3",
                        "-O",
                        ".",
                        "-o",
                        "v526",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = generated_dir / f"v526_{mode}.f90"
                self.assertTrue(source.is_file())
                self.assertTrue((generated_dir / f"v526_{mode}.msg").is_file())
                compiled = compile_source(
                    source, output / f"v526_{mode}.o", output / f"mod-{suffix}"
                )
                self.assertNotEqual(compiled.returncode, 0)
                self.assertIn(expected_compile_markers[mode], compiled.stderr)

    def test_exact_fortad_refusal_bounded_runtime_and_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v526-fortad-") as directory:
            output = Path(directory)
            commands = (
                [
                    "check",
                    "--proc",
                    "SING3",
                    "--output",
                    str(output / "parser.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
                [
                    "--mode",
                    "forward",
                    "--indep",
                    "DXP,DYP",
                    "--proc",
                    "SING3",
                    "--name",
                    "v526_exact_forward",
                    "--module",
                    "v526_exact_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
                [
                    "--mode",
                    "reverse",
                    "--indep",
                    "DXP,DYP",
                    "--dep",
                    "DYP",
                    "--proc",
                    "SING3",
                    "--name",
                    "v526_exact_reverse",
                    "--module",
                    "v526_exact_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                    str(SOURCE_DIR / "program.f90"),
                ],
            )
            for command, filename in zip(commands, ("parser.f90", "forward.f90", "reverse.f90")):
                completed = run([str(FORTAD), *command])
                self.assertNotEqual(completed.returncode, 0, completed.stdout)
                self.assertIn(
                    "unsupported allocation lifetime construct 'allocate' at line 233",
                    completed.stderr,
                )
                self.assertFalse((output / filename).exists())

            port_forward = run(
                [
                    str(FORTAD),
                    "--mode",
                    "forward",
                    "--indep",
                    "dxp,dyp_initial",
                    "--dep",
                    "dyp",
                    "--proc",
                    "v526_sing3",
                    "--name",
                    "v526_port_forward",
                    "--module",
                    "v526_port_forward_mod",
                    "--output",
                    str(output / "port-forward.f90"),
                    str(CASE / "port.f90"),
                ]
            )
            port_reverse = run(
                [
                    str(FORTAD),
                    "--mode",
                    "reverse",
                    "--indep",
                    "dxp,dyp_initial",
                    "--dep",
                    "dyp",
                    "--proc",
                    "v526_sing3",
                    "--name",
                    "v526_port_reverse",
                    "--module",
                    "v526_port_reverse_mod",
                    "--output",
                    str(output / "port-reverse.f90"),
                    str(CASE / "port.f90"),
                ]
            )
            self.assertEqual(port_forward.returncode, 0, port_forward.stdout + port_forward.stderr)
            self.assertEqual(port_reverse.returncode, 0, port_reverse.stdout + port_reverse.stderr)
            self.assertTrue((output / "port-forward.f90").is_file())
            self.assertTrue((output / "port-reverse.f90").is_file())

            port = compile_source(CASE / "port.f90", output / "port.o", output / "port-mod")
            forward = compile_source(
                output / "port-forward.f90", output / "port-forward.o", output / "port-mod"
            )
            reverse = compile_source(
                output / "port-reverse.f90", output / "port-reverse.o", output / "port-mod"
            )
            harness = compile_source(
                CASE / "harness.f90", output / "harness.o", output / "port-mod"
            )
            for compiled in (port, forward, reverse, harness):
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            linked = run(
                [
                    FC,
                    "-o",
                    str(output / "harness"),
                    str(output / "port.o"),
                    str(output / "port-forward.o"),
                    str(output / "port-reverse.o"),
                    str(output / "harness.o"),
                ]
            )
            self.assertEqual(linked.returncode, 0, linked.stdout + linked.stderr)
            executed = run([str(output / "harness")])
            self.assertEqual(executed.returncode, 0, executed.stdout + executed.stderr)
            self.assertIn("harness_status: pass", executed.stdout)

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_status: pass", oracle.stdout)
        self.assertIn("adjoint_identity_residual:", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
