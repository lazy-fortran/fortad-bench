#!/usr/bin/env python3
"""Exactly three independent contracts for the lh081 external-call boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad"))
SOURCE = UPSTREAM / "nonRegressions" / "set01" / "lh081"
TAPENADE = UPSTREAM / "bin" / "tapenade"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
STRICT = (
    "-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only",
    "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto",
)


def completed(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, check=False)


class Lh081ContractTests(unittest.TestCase):
    def test_independent_call_graph_and_derivative_oracle(self) -> None:
        result = completed(["python3", str(CASE / "oracle.py"), str(SOURCE)])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("oracle_source_call_graph: pass", result.stdout)
        self.assertIn("oracle_status: pass", result.stdout)

    def test_fresh_tapenade_generation_and_strict_compilation(self) -> None:
        self.assertTrue(TAPENADE.is_file())
        with tempfile.TemporaryDirectory(prefix="lh081-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, stem in (("p", "lh081_p"), ("d", "lh081_d"), ("b", "lh081_b")):
                output = work / mode
                output.mkdir()
                options = [] if mode == "p" else ["-root", "test2"]
                generated = completed([
                    str(TAPENADE), f"-{mode}", *options, "-O", str(output),
                    "-o", "lh081", str(SOURCE / "program.f"),
                ])
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"{stem}.f"
                self.assertTrue(source.is_file())
                compiled = completed(["gfortran", *STRICT, str(source), "-o", str(work / f"{stem}.o")])
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_fortad_exact_forward_and_reverse_refuse_without_output(self) -> None:
        self.assertTrue(FORTAD.is_file())
        with tempfile.TemporaryDirectory(prefix="lh081-contract-fortad-") as temporary:
            work = Path(temporary)
            forward_path = work / "forward.f90"
            forward = completed([
                str(FORTAD), "--mode", "forward", "--indep", "a", "--proc", "test2",
                "--name", "lh081_forward", "--module", "lh081_forward_mod",
                "--output", str(forward_path), str(SOURCE / "program.f"),
            ])
            self.assertNotEqual(forward.returncode, 0)
            self.assertIn("inlining test would need a statement form it does not have", forward.stdout + forward.stderr)
            self.assertFalse(forward_path.exists())

            reverse_path = work / "reverse.f90"
            reverse = completed([
                str(FORTAD), "--mode", "reverse", "--indep", "a", "--dep", "a",
                "--proc", "test2", "--name", "lh081_reverse", "--module", "lh081_reverse_mod",
                "--output", str(reverse_path), str(SOURCE / "program.f"),
            ])
            self.assertNotEqual(reverse.returncode, 0)
            self.assertIn("inlining test would need a statement form it does not have", reverse.stdout + reverse.stderr)
            self.assertFalse(reverse_path.exists())


if __name__ == "__main__":
    unittest.main()
