#!/usr/bin/env python3
"""Exactly three behavioral tests for the pinned v385 boundary."""

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


def existing_path(env_name: str, *candidates: Path) -> Path:
    configured = os.environ.get(env_name)
    options = ([Path(configured)] if configured else []) + list(candidates)
    for candidate in options:
        if candidate.is_dir():
            return candidate
    raise AssertionError(f"no {env_name} checkout found: {options}")


UPSTREAM = existing_path(
    "TAPENADE_REPO",
    BENCH / "upstream" / "tapenade",
    Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"),
)
FORTAD_ROOT = existing_path(
    "FORTAD_REPO",
    BENCH.parent / "fortad",
    Path("/mnt/storage/code/lazy-fortran/fortad"),
)
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v385"
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compile_source(
    compiler: str,
    source: Path,
    output: Path,
    modules: Path,
    extra: list[str] | None = None,
) -> subprocess.CompletedProcess[str]:
    modules.mkdir(parents=True, exist_ok=True)
    command = [
        compiler,
        *STRICT_FLAGS,
        f"-I{SOURCE_DIR}",
        *(extra or []),
        f"-J{modules}",
        "-c",
        str(source),
        "-o",
        str(output),
    ]
    return subprocess.run(command, capture_output=True, text=True, check=False)


class V385ContractTests(unittest.TestCase):
    def test_exact_upstream_strict_compile_behavior(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["source_form"], "free")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(manifest["selected_entry_points"], ["fonctiontTest(buf,resultat)"])
        for name, digest in manifest["upstream_sha256"].items():
            source = SOURCE_DIR / name
            self.assertTrue(source.is_file(), source)
            self.assertEqual(sha256(source), digest, name)

        compiler = os.environ.get("FC", "mpifort")
        with tempfile.TemporaryDirectory(prefix="fortad-v385-exact-") as directory:
            output = Path(directory)
            for name in ("program.f90", "program_d.f90", "program_b.f90"):
                completed = compile_source(
                    compiler,
                    SOURCE_DIR / name,
                    output / f"{name}.o",
                    output / f"{name}-mod",
                )
                diagnostic = completed.stdout + completed.stderr
                self.assertNotEqual(completed.returncode, 0, name)
                self.assertIn("Nonstandard type declaration REAL*8", diagnostic, name)

        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )

    def test_fresh_tapenade_generation_and_strict_compile_behavior(self) -> None:
        compiler = os.environ.get("FC", "mpifort")
        with tempfile.TemporaryDirectory(prefix="fortad-v385-tapenade-") as directory:
            output = Path(directory)
            support = output / "support"
            admpi = compile_source(
                compiler,
                UPSTREAM / "ADFirstAidKit" / "adMPI.f90",
                output / "admpi.o",
                support,
            )
            self.assertEqual(admpi.returncode, 0, admpi.stderr)

            for mode, option, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                mode_dir = output / mode
                mode_dir.mkdir()
                generated = subprocess.run(
                    [
                        str(TAPENADE),
                        option,
                        "-root",
                        "fonctiontTest",
                        "-O",
                        ".",
                        "-o",
                        "v385",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=mode_dir,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(generated.returncode, 0, generated.stderr)
                self.assertIn("mpi_test", generated.stdout + generated.stderr)
                source = mode_dir / f"v385_{suffix}.f90"
                message = mode_dir / f"v385_{suffix}.msg"
                self.assertTrue(source.is_file(), source)
                self.assertTrue(message.is_file(), message)
                extra = [f"-I{support}"] if mode != "parser" else []
                compiled = compile_source(
                    compiler,
                    source,
                    mode_dir / "generated.o",
                    mode_dir / "mod",
                    extra,
                )
                self.assertNotEqual(compiled.returncode, 0, mode)
                self.assertIn(
                    "Nonstandard type declaration REAL*8",
                    compiled.stdout + compiled.stderr,
                    mode,
                )

    def test_fortad_exact_modes_refuse_and_independent_oracle_passes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-v385-exact-") as directory:
            output = Path(directory)
            commands = {
                "parser": [
                    "check",
                    "--proc",
                    "fonctiontTest",
                    "--output",
                    str(output / "parser.f90"),
                ],
                "forward": [
                    "--mode",
                    "forward",
                    "--proc",
                    "fonctiontTest",
                    "--indep",
                    "buf",
                    "--name",
                    "v385_forward",
                    "--module",
                    "v385_forward_mod",
                    "--output",
                    str(output / "forward.f90"),
                ],
                "reverse": [
                    "--mode",
                    "reverse",
                    "--proc",
                    "fonctiontTest",
                    "--indep",
                    "buf",
                    "--dep",
                    "resultat",
                    "--name",
                    "v385_reverse",
                    "--module",
                    "v385_reverse_mod",
                    "--output",
                    str(output / "reverse.f90"),
                ],
            }
            for mode, arguments in commands.items():
                completed = subprocess.run(
                    [str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertNotEqual(completed.returncode, 0, mode)
                self.assertIn(
                    "unsupported allocation lifetime construct 'allocatable declaration/component' at line 11",
                    completed.stdout + completed.stderr,
                    mode,
                )
                self.assertFalse((output / f"{mode}.f90").exists(), mode)

        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("oracle_status: pass local-square-map", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
