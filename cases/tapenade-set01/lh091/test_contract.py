#!/usr/bin/env python3
"""Independent contracts for the exact lh091 evidence."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade"))).resolve()
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")).resolve()
SOURCE_DIR = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh091"
FORTAD_PIN = "150e663dbad239a3a11a679e3dcf16be76496f8d"
TAPENADE_PIN = "e59864cab441d4175df75383b3ff58c3dcd26df9"
STRICT = ("-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-I", str(SOURCE_DIR))
LEGACY = ("-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-Wall", "-Wextra", "-Wimplicit-interface", "-fsyntax-only", "-I", str(SOURCE_DIR))


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class Lh091ContractTests(unittest.TestCase):
    def test_independent_three_case_behavioral_oracle(self) -> None:
        completed = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR)])
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        for marker in ("oracle_ff: pass", "oracle_bugequiv_update: 3 hidden-state cases pass", "oracle_jvp_finite_difference: pass", "oracle_vjp_adjoint_identity: pass", "oracle_behavioral_cases: 3", "oracle_status: pass"):
            self.assertIn(marker, completed.stdout)

    def test_fresh_tapenade_and_compile_gates(self) -> None:
        tapenade = UPSTREAM_ROOT / "bin" / "tapenade"
        self.assertTrue(tapenade.is_file())
        pinned = run(["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD"])
        self.assertEqual(pinned.stdout.strip(), TAPENADE_PIN, pinned.stderr)
        for name in ("program.f", "program_p.f", "program_d.f", "program_b.f", "program_dv.f"):
            self.assertTrue((SOURCE_DIR / name).is_file())
        with tempfile.TemporaryDirectory(prefix="lh091-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, flag, suffix, root in (("parser", "-p", "p", None), ("forward", "-d", "d", "bugequiv"), ("reverse", "-b", "b", "bugequiv")):
                output = work / mode
                output.mkdir()
                command = [str(tapenade), flag]
                if root is not None:
                    command += ["-root", root]
                command += ["-O", str(output), "-o", "lh091", str(SOURCE_DIR / "program.f")]
                generated = run(command)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"lh091_{suffix}.f"
                self.assertTrue(source.is_file() and source.stat().st_size > 0)
                for flags in (STRICT, LEGACY):
                    compiled = run(["gfortran", *flags, str(source)])
                    self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
        for name in ("program.f", "program_p.f", "program_d.f", "program_b.f"):
            for flags in (STRICT, LEGACY):
                compiled = run(["gfortran", *flags, str(SOURCE_DIR / name)])
                self.assertEqual(compiled.returncode, 0, f"{name}: {compiled.stdout}{compiled.stderr}")
        for flags in (STRICT, LEGACY):
            missing = run(["gfortran", *flags, str(SOURCE_DIR / "program_dv.f")])
            self.assertNotEqual(missing.returncode, 0)
            self.assertIn("DIFFSIZES.inc", missing.stdout + missing.stderr)

    def test_fortad_source_first_and_compatibility_refuse(self) -> None:
        fortad = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
        self.assertTrue(fortad.is_file())
        pinned = run(["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"])
        self.assertEqual(pinned.stdout.strip(), FORTAD_PIN, pinned.stderr)
        with tempfile.TemporaryDirectory(prefix="lh091-contract-fortad-") as temporary:
            work = Path(temporary)
            commands = (
                [str(fortad), "check", "--proc", "bugequiv", "--output", str(work / "source-check.f90"), str(SOURCE_DIR / "program.f")],
                [str(fortad), "jvp", "c", "--proc", "bugequiv", "--name", "lh091_jvp", "--module", "lh091_jvp_mod", "--output", str(work / "source-jvp.f90"), str(SOURCE_DIR / "program.f")],
                [str(fortad), "vjp", "c", "--dep", "c", "--proc", "bugequiv", "--name", "lh091_vjp", "--module", "lh091_vjp_mod", "--output", str(work / "source-vjp.f90"), str(SOURCE_DIR / "program.f")],
                [str(fortad), "-p", "-O", str(work / "compat-p"), "-o", "lh091", str(SOURCE_DIR / "program.f")],
                [str(fortad), "-d", "-root", "bugequiv", "-O", str(work / "compat-d"), "-o", "lh091", str(SOURCE_DIR / "program.f")],
                [str(fortad), "-b", "-root", "bugequiv", "-O", str(work / "compat-b"), "-o", "lh091", str(SOURCE_DIR / "program.f")],
            )
            for command in commands:
                completed = run(command)
                self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertIn("unsupported statement at line 7", completed.stdout + completed.stderr)
            for path in work.glob("*.f90"):
                self.fail(f"FortAD emitted unexpected output {path}")


if __name__ == "__main__":
    unittest.main(verbosity=1)
