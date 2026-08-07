#!/usr/bin/env python3
"""Three independent behavioral contracts for the lh087 exact-source boundary."""

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
SOURCE = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh087"
STRICT = [
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-pedantic-errors",
    "-Wall", "-Wextra", "-Wimplicit-interface",
]


class Lh087ContractTests(unittest.TestCase):
    def test_independent_source_semantic_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py"), str(SOURCE)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_source_index_domain: expected-refusal", completed.stdout)
        self.assertIn("oracle_program_dv.f: expected-refusal", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_artifacts_compile(self) -> None:
        tapenade = UPSTREAM_ROOT / "bin" / "tapenade"
        self.assertTrue(tapenade.is_file())
        with tempfile.TemporaryDirectory(prefix="lh087-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, directory, stem in (("p", "parser", "lh087_p"), ("d", "forward", "lh087_d"), ("b", "reverse", "lh087_b")):
                output = work / directory
                output.mkdir()
                generated = subprocess.run(
                    [str(tapenade), f"-{mode}", "-root", "nl_model_mie", "-O", str(output), "-o", "lh087", str(SOURCE / "program.f")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"{stem}.f"
                self.assertTrue(source.is_file())
                compiled = subprocess.run(
                    ["gfortran", *STRICT, "-c", str(source), "-o", str(work / f"{stem}.o")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_fortad_exact_forward_and_reverse_boundary(self) -> None:
        fortad = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
        self.assertTrue(fortad.is_file())
        with tempfile.TemporaryDirectory(prefix="lh087-contract-fortad-") as temporary:
            work = Path(temporary)
            common = ["--indep", "phase", "--indep", "number", "--indep", "sigma", "--dep", "pp", "--proc", "nl_model_mie"]
            forward_path = work / "forward.f90"
            forward = subprocess.run(
                [str(fortad), "--mode", "forward", *common, "--name", "lh087_forward", "--module", "lh087_forward_mod", "--output", str(forward_path), str(SOURCE / "program.f")],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(forward.returncode, 0, forward.stdout + forward.stderr)
            self.assertTrue(forward_path.is_file())
            warning_gate = subprocess.run(
                ["gfortran", "-std=f2018", "-ffree-form", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-Werror=uninitialized", "-c", str(forward_path), "-o", str(work / "forward.o")],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(warning_gate.returncode, 0)
            self.assertIn("uninitialized", warning_gate.stdout.lower() + warning_gate.stderr.lower())

            reverse_path = work / "reverse.f90"
            reverse = subprocess.run(
                [str(fortad), "--mode", "reverse", *common, "--name", "lh087_reverse", "--module", "lh087_reverse_mod", "--output", str(reverse_path), str(SOURCE / "program.f")],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(reverse.returncode, 0)
            self.assertIn("dependent 'pp' is not declared in NL_MODEL_MIE", reverse.stdout + reverse.stderr)
            self.assertFalse(reverse_path.exists())


if __name__ == "__main__":
    unittest.main()
