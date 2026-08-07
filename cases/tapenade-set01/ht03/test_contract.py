#!/usr/bin/env python3
"""Exactly three independent contracts for the ht03 boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade"))
).resolve()
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")
).resolve()
SOURCE = UPSTREAM_ROOT / "nonRegressions" / "set01" / "ht03"
STRICT_FIXED = [
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only",
    "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
]
LEGACY_FIXED = [
    "-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only",
    "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
]
STRICT_FREE = [
    "-std=f2018", "-ffree-form", "-ffree-line-length-none", "-fsyntax-only",
    "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
]


class Ht03ContractTests(unittest.TestCase):
    def test_independent_three_behavior_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(SOURCE)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        for marker in (
            "oracle_source_shape: top/sub1 call and external read inventory pass",
            "oracle_jvp: conditional arithmetic model agrees with central differences",
            "oracle_vjp: conditional Jacobian-transpose dot-product identity passes",
            "oracle_status: pass",
        ):
            self.assertIn(marker, completed.stdout)

    def test_fresh_tapenade_generation_with_both_compiler_gates(self) -> None:
        tapenade = UPSTREAM_ROOT / "bin" / "tapenade"
        self.assertTrue(tapenade.is_file())
        with tempfile.TemporaryDirectory(prefix="ht03-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, option, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                output = work / mode
                output.mkdir()
                command = [str(tapenade), option]
                if mode != "parser":
                    command += ["-root", "top"]
                command += ["-O", str(output), "-o", "ht03", str(SOURCE / "program.f")]
                generated = subprocess.run(
                    command, cwd=UPSTREAM_ROOT, capture_output=True, text=True, check=False
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"ht03_{suffix}.f"
                self.assertTrue(source.is_file())
                for label, flags in (("strict", STRICT_FIXED), ("legacy", LEGACY_FIXED)):
                    compiled = subprocess.run(
                        ["gfortran", *flags, str(source)],
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(
                        compiled.returncode,
                        0,
                        f"{mode} {label}: {compiled.stdout}{compiled.stderr}",
                    )

    def test_exact_fortad_check_and_refusal_boundaries(self) -> None:
        fortad = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
        self.assertTrue(fortad.is_file())
        with tempfile.TemporaryDirectory(prefix="ht03-contract-fortad-") as temporary:
            work = Path(temporary)
            checked = work / "checked.f90"
            check = subprocess.run(
                [str(fortad), "check", "--output", str(checked), str(SOURCE / "program.f")],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertTrue(checked.is_file())
            compiled = subprocess.run(
                ["gfortran", *STRICT_FREE, str(checked)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

            probes = (
                (
                    "top-forward",
                    [str(fortad), "--mode", "forward", "--indep", "i1,i2,i3", "--proc", "top",
                     "--name", "ht03_jvp", "--module", "ht03_jvp_mod", "--output",
                     str(work / "top-forward.f90"), str(SOURCE / "program.f")],
                    "no derivative rule for the call to 'sub1'",
                    work / "top-forward.f90",
                ),
                (
                    "top-reverse",
                    [str(fortad), "--mode", "reverse", "--indep", "i1,i2,i3", "--dep", "o1",
                     "--proc", "top", "--name", "ht03_vjp", "--module", "ht03_vjp_mod",
                     "--output", str(work / "top-reverse.f90"), str(SOURCE / "program.f")],
                    "no reverse rule for the call to 'sub1'",
                    work / "top-reverse.f90",
                ),
                (
                    "sub1-forward",
                    [str(fortad), "--mode", "forward", "--indep", "i1,i2", "--proc", "sub1",
                     "--name", "ht03_sub1_jvp", "--module", "ht03_sub1_jvp_mod", "--output",
                     str(work / "sub1-forward.f90"), str(SOURCE / "program.f")],
                    "unsupported statement at line 17",
                    work / "sub1-forward.f90",
                ),
                (
                    "sub1-reverse",
                    [str(fortad), "--mode", "reverse", "--indep", "i1,i2", "--dep", "o1",
                     "--proc", "sub1", "--name", "ht03_sub1_vjp", "--module", "ht03_sub1_vjp_mod",
                     "--output", str(work / "sub1-reverse.f90"), str(SOURCE / "program.f")],
                    "unsupported statement at line 17",
                    work / "sub1-reverse.f90",
                ),
            )
            for label, command, diagnostic, output in probes:
                with self.subTest(label=label):
                    completed = subprocess.run(
                        command, capture_output=True, text=True, check=False
                    )
                    self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                    self.assertIn(diagnostic, completed.stdout + completed.stderr)
                    self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
