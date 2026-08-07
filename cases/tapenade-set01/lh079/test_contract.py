#!/usr/bin/env python3
"""Three independent behavioral tests for the lh079 exact-source boundary."""

from __future__ import annotations

import hashlib
import os
import re
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_CHECKOUT = Path(os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad")))
SOURCE = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh079"
TAPENADE = UPSTREAM_ROOT / "bin" / "tapenade"
FORTAD_REVISION = "7adc75030db3fa4422339d82d2725ae29ee13dac"
TAPENADE_REVISION = "e59864cab441d4175df75383b3ff58c3dcd26df9"
FLAGS = [
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-cpp",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Lh079ContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fortad_temp = None
        current_commit = subprocess.run(
            ["git", "-C", str(FORTAD_CHECKOUT), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        dirty = subprocess.run(
            ["git", "-C", str(FORTAD_CHECKOUT), "status", "--porcelain", "--untracked-files=no"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        if current_commit != FORTAD_REVISION or dirty:
            cls.fortad_temp = tempfile.TemporaryDirectory(prefix="fortad-lh079-clean-")
            clone = Path(cls.fortad_temp.name) / "fortad"
            subprocess.run(["git", "clone", "--shared", "--quiet", str(FORTAD_CHECKOUT), str(clone)], check=True)
            for dependency in ("fortfront", "fortgen"):
                source_dependency = FORTAD_CHECKOUT.parent / dependency
                if source_dependency.is_dir():
                    (clone.parent / dependency).symlink_to(source_dependency)
            subprocess.run(["git", "-C", str(clone), "checkout", "--detach", "--quiet", FORTAD_REVISION], check=False)
            self_commit = subprocess.run(
                ["git", "-C", str(clone), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip()
            if self_commit != FORTAD_REVISION:
                raise RuntimeError(f"temporary FortAD checkout is {self_commit}, expected {FORTAD_REVISION}")
            subprocess.run(["fo", "build"], cwd=clone, check=True, stdout=subprocess.DEVNULL)
            cls.fortad_root = clone
        else:
            cls.fortad_root = FORTAD_CHECKOUT
        cls.fortad = cls.fortad_root / "build" / "fo" / "bin" / "fortad"

    def test_independent_source_oracle_and_arithmetic_behavior(self) -> None:
        source = SOURCE / "program.f"
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(source)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        text = source.read_text(encoding="utf-8").lower()
        self.assertIn("double precision function f(t,a,ad,b,bd,x)", text)
        self.assertEqual(len(re.findall(r"\bxd\b", text)), 1)
        self.assertIn("x**-0.5d0", text)
        self.assertIn("b(2)", text)
        self.assertIn("bd(2)", text)

    def test_fresh_tapenade_and_strict_compiler_boundary(self) -> None:
        self.assertTrue(TAPENADE.is_file(), TAPENADE)
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip(),
            TAPENADE_REVISION,
        )
        with tempfile.TemporaryDirectory(prefix="fortad-lh079-tapenade-") as directory:
            output = Path(directory)
            module = output / "mod"
            module.mkdir()

            def compile_fixed(label: str, path: Path) -> subprocess.CompletedProcess[str]:
                return subprocess.run(
                    [
                        "gfortran",
                        *FLAGS,
                        f"-I{SOURCE}",
                        f"-J{module}",
                        "-c",
                        str(path),
                        "-o",
                        str(output / f"{label}.o"),
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )

            primal = compile_fixed("primal", SOURCE / "program.f")
            self.assertNotEqual(primal.returncode, 0)
            self.assertIn("Syntax error in expression", primal.stderr)
            for name in ("program_p.f", "program_d.f", "program_b.f"):
                compiled = compile_fixed(name, SOURCE / name)
                self.assertEqual(compiled.returncode, 0, name + compiled.stderr)
            multidirectional = compile_fixed("program_dv", SOURCE / "program_dv.f")
            self.assertNotEqual(multidirectional.returncode, 0)
            self.assertIn("Cannot open included file", multidirectional.stderr)

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
                        "f",
                        "-O",
                        ".",
                        "-o",
                        "lh079",
                        str(SOURCE / "program.f"),
                    ],
                    cwd=mode_dir,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                generated_source = mode_dir / f"lh079_{suffix}.f"
                self.assertTrue(generated_source.is_file(), generated_source)
                fresh = compile_fixed(f"fresh_{mode}", generated_source)
                self.assertEqual(fresh.returncode, 0, mode + fresh.stderr)

    def test_fortad_exact_parser_and_derivative_boundaries(self) -> None:
        self.assertTrue(self.fortad.is_file(), self.fortad)
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(self.fortad_root), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip(),
            FORTAD_REVISION,
        )
        with tempfile.TemporaryDirectory(prefix="fortad-lh079-exact-") as directory:
            output = Path(directory)
            parser = subprocess.run(
                [
                    str(self.fortad),
                    "check",
                    "--proc",
                    "f",
                    "--output",
                    str(output / "parser.f90"),
                    str(SOURCE / "program.f"),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(parser.returncode, 0, parser.stderr)
            self.assertTrue((output / "parser.f90").is_file())
            requests = (
                (
                    "forward",
                    [
                        "--mode",
                        "forward",
                        "--proc",
                        "f",
                        "--indep",
                        "a,ad,b,bd,x",
                        "--output",
                        str(output / "forward.f90"),
                    ],
                ),
                (
                    "reverse",
                    [
                        "--mode",
                        "reverse",
                        "--proc",
                        "f",
                        "--indep",
                        "a,ad,b,bd,x",
                        "--dep",
                        "f",
                        "--output",
                        str(output / "reverse.f90"),
                    ],
                ),
            )
            expected_diagnostics = {
                "forward": "fortad: independent 'ad' is not declared in f",
                "reverse": "fortad: dependent 'f' is not declared in f",
            }
            for label, arguments in requests:
                completed = subprocess.run(
                    [str(self.fortad), *arguments, str(SOURCE / "program.f")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertNotEqual(completed.returncode, 0, label)
                self.assertIn(expected_diagnostics[label], completed.stderr, label)
                self.assertFalse((output / f"{label}.f90").exists(), label)

        report = (CASE / "result.txt").read_text(encoding="utf-8")
        self.assertIn("classification: unsupported-invalid-upstream-fortran", report)
        self.assertIn("tapenade_generation: parser=0 forward=0 reverse=0", report)
        self.assertIn("fortad_exact_parser: pass status=0", report)
        self.assertIn("fortad_exact_forward: expected-refusal status=1", report)
        self.assertIn("fortad_exact_reverse: expected-refusal status=1", report)
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], TAPENADE_REVISION)
        self.assertEqual(manifest["fortad_revision"], FORTAD_REVISION)
        for name, expected in manifest["upstream_sha256"].items():
            self.assertEqual(sha256(UPSTREAM_ROOT / name), expected, name)


if __name__ == "__main__":
    unittest.main(verbosity=1)
