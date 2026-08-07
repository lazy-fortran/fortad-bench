#!/usr/bin/env python3
"""Three independent behavioral contracts for the lh089 boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh089"
STRICT = [
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors",
    "-Wall", "-Wextra", "-Wimplicit-interface",
]
LEGACY = [
    "-std=legacy", "-ffixed-form", "-ffixed-line-length-none",
    "-Wall", "-Wextra", "-Wimplicit-interface",
]


def compile_source(source: Path, output: Path, flags: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["gfortran", *flags, "-c", str(source), "-o", str(output)],
        capture_output=True,
        text=True,
        check=False,
    )


class Lh089ContractTests(unittest.TestCase):
    def test_independent_pushpop_semantic_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(SOURCE)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_pushpop_state_machine: pass", completed.stdout)
        self.assertIn("oracle_jvp_finite_difference: pass", completed.stdout)
        self.assertIn("oracle_vjp_adjoint_identity: pass", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_generation_and_compiler_boundary(self) -> None:
        tapenade = UPSTREAM_ROOT / "bin" / "tapenade"
        dependency = SOURCE / "PUSHPOPGeneralLib"
        self.assertTrue(tapenade.is_file())
        self.assertTrue(dependency.is_file())
        with tempfile.TemporaryDirectory(prefix="lh089-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, directory, stem in (("p", "parser", "lh089_p"),
                                          ("d", "forward", "lh089_d"),
                                          ("b", "reverse", "lh089_b")):
                output = work / directory
                output.mkdir()
                generated = subprocess.run(
                    [str(tapenade), f"-{mode}", "-root", "pushpop",
                     "-ext", str(dependency), "-O", str(output), "-o", "lh089",
                     str(SOURCE / "program.f")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"{stem}.f"
                self.assertTrue(source.is_file())
                legacy = compile_source(source, work / f"{stem}-legacy.o", LEGACY)
                self.assertEqual(legacy.returncode, 0, legacy.stdout + legacy.stderr)
                strict = compile_source(source, work / f"{stem}-strict.o", STRICT)
                strict_log = strict.stdout + strict.stderr
                self.assertNotEqual(strict.returncode, 0)
                self.assertIn("nonstandard type declaration REAL*8".lower(), strict_log.lower())

    def test_fortad_exact_check_forward_reverse_boundary(self) -> None:
        fortad = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
        self.assertTrue(fortad.is_file())
        with tempfile.TemporaryDirectory(prefix="lh089-contract-fortad-") as temporary:
            work = Path(temporary)
            checked = work / "checked.f90"
            check = subprocess.run(
                [str(fortad), "check", "--proc", "pushpop", "--output", str(checked), str(SOURCE / "program.f")],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            checked_text = checked.read_text(encoding="utf-8").lower()
            self.assertIn("subroutine pushpop", checked_text)
            self.assertNotIn("real*8", checked_text)

            forward = subprocess.run(
                [str(fortad), "--mode", "forward", "--indep", "a,b", "--proc", "pushpop",
                 "--output", str(work / "forward.f90"), str(SOURCE / "program.f")],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(forward.returncode, 0)
            self.assertIn("independent 'a' is not declared in pushpop", forward.stdout + forward.stderr)
            self.assertFalse((work / "forward.f90").exists())

            reverse = subprocess.run(
                [str(fortad), "--mode", "reverse", "--indep", "a,b", "--dep", "a",
                 "--proc", "pushpop", "--output", str(work / "reverse.f90"), str(SOURCE / "program.f")],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(reverse.returncode, 0)
            self.assertIn("dependent 'a' is not declared in pushpop", reverse.stdout + reverse.stderr)
            self.assertFalse((work / "reverse.f90").exists())


if __name__ == "__main__":
    unittest.main()
