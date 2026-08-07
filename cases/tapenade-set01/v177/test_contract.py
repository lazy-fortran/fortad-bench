#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the v177 no-entry boundary."""

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
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
)
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set05" / "v177"
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
TAPENADE = UPSTREAM_ROOT / "bin" / "tapenade"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"
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


def compile_source(source: Path, output: Path, module_dir: Path) -> subprocess.CompletedProcess[str]:
    module_dir.mkdir(parents=True, exist_ok=True)
    return run(
        [
            os.environ.get("FC", "gfortran"),
            *STRICT_FLAGS,
            f"-I{UPSTREAM}",
            f"-J{module_dir}",
            "-c",
            str(source),
            "-o",
            str(output),
        ]
    )


class V177ContractTests(unittest.TestCase):
    def test_tracked_inventory_and_strict_exact_reference_compilation(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-no-entry-point-module-only")
        self.assertEqual(manifest["selected_entry_points"], [])
        self.assertEqual(manifest["stored_references"], ["program_p.f90", "program_p.msg"])
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "3a946d34d3caa7a75fb6f891139023650b4ce51a")
        tracked = run(
            ["git", "-C", str(UPSTREAM_ROOT), "ls-files", "nonRegressions/set05/v177"]
        ).stdout.splitlines()
        self.assertEqual(
            tracked,
            [
                "nonRegressions/set05/v177/program.f90",
                "nonRegressions/set05/v177/program_p.f90",
                "nonRegressions/set05/v177/program_p.msg",
            ],
        )
        for relative, digest in manifest["upstream_sha256"].items():
            source = UPSTREAM_ROOT / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest, relative)

        with tempfile.TemporaryDirectory(prefix="fortad-v177-compile-") as directory:
            output = Path(directory)
            primal = compile_source(UPSTREAM / "program.f90", output / "primal.o", output / "mod")
            parser = compile_source(UPSTREAM / "program_p.f90", output / "parser.o", output / "mod")
        self.assertNotEqual(primal.returncode, 0, primal.stdout + primal.stderr)
        self.assertNotEqual(parser.returncode, 0, parser.stdout + parser.stderr)
        self.assertIn("Nonconforming tab character", primal.stderr)
        self.assertIn("Nonstandard type declaration", primal.stderr)
        self.assertIn("Nonstandard type declaration", parser.stderr)

    def test_fresh_tapenade_no_root_boundary_and_parser_strict_refusal(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        with tempfile.TemporaryDirectory(prefix="fortad-v177-tapenade-") as directory:
            output = Path(directory)
            modes = (("parser", "-p", "v177_p", "v177_p_p.f90", "v177_p_p.msg"),
                     ("tangent", "-d", "v177_d", "v177_d_d.f90", "v177_d_d.msg"),
                     ("reverse", "-b", "v177_b", "v177_b_b.f90", "v177_b_b.msg"))
            for label, mode, base, source_name, message_name in modes:
                generated_dir = output / label
                generated_dir.mkdir()
                generated = run(
                    [str(TAPENADE), mode, "-O", ".", "-o", base, str(UPSTREAM / "program.f90")],
                    cwd=generated_dir,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                self.assertTrue((generated_dir / message_name).is_file())
                if label == "parser":
                    self.assertTrue((generated_dir / source_name).is_file())
                    compiled = compile_source(
                        generated_dir / source_name, output / "parser.o", output / "parser-mod"
                    )
                    self.assertNotEqual(compiled.returncode, 0)
                    self.assertIn("Nonstandard type declaration", compiled.stderr)
                else:
                    self.assertFalse((generated_dir / source_name).exists())
                    message = (generated_dir / message_name).read_text(encoding="utf-8")
                    self.assertIn("No root unit to differentiate", message)
                    self.assertIn("The code provided does not contain a top procedure", message)

    def test_fortad_no_entry_boundary_and_independent_module_oracle(self) -> None:
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v177-fortad-") as directory:
            output = Path(directory)
            commands = (
                ["check", "--output", str(output / "parser.f90"), str(UPSTREAM / "program.f90")],
                ["--mode", "forward", "--indep", "X", "--name", "v177_forward",
                 "--output", str(output / "forward.f90"), str(UPSTREAM / "program.f90")],
                ["--mode", "reverse", "--indep", "X", "--dep", "Y", "--name", "v177_reverse",
                 "--output", str(output / "reverse.f90"), str(UPSTREAM / "program.f90")],
            )
            for command, filename in zip(commands, ("parser.f90", "forward.f90", "reverse.f90")):
                completed = run([str(FORTAD), *command])
                self.assertNotEqual(completed.returncode, 0, completed.stdout)
                self.assertIn("fortad: no function or subroutine found in source", completed.stderr)
                self.assertFalse((output / filename).exists())

        oracle = run(["python3", str(CASE / "oracle.py")])
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_entry_point: none (module-only unit)", oracle.stdout)
        self.assertIn("oracle_storage_elements:", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-no-entry-point-module-only",
            "upstream_exact_strict_compile: program.f90=1 program_p.f90=1",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=1 tangent=not-applicable-no-source reverse=not-applicable-no-source",
            "fortad_exact_parser: expected-refusal status=1 output=none",
            "fortad_exact_forward: expected-refusal status=1 output=none",
            "fortad_exact_reverse: expected-refusal status=1 output=none",
            "port_result: not-claimed reason=no-callable-procedure-interface",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main(verbosity=1)
