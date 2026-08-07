#!/usr/bin/env python3
"""Three behavioral contracts for the exact pinned lh096 boundary case."""
from __future__ import annotations
import hashlib
import os
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
SOURCE_DIR = BENCH / "upstream/tapenade/nonRegressions/set01/lh096"
TAPENADE = Path(os.environ.get("TAPENADE_REPO", str(BENCH / "upstream/tapenade"))) / "bin/tapenade"
FORTAD = Path(os.environ.get("FORTAD_REPO", "/home/ert/code/lazy-fortran/fortad")) / "build/fo/bin/fortad"
STRICT_FIXED = ["-std=f2018", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto"]
LEGACY_FIXED = ["-std=legacy", "-ffixed-form", "-ffixed-line-length-none", "-fsyntax-only", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto"]
STRICT_FREE = ["-std=f2018", "-ffree-form", "-fsyntax-only", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-fno-lto"]

def compile_gate(source: Path, flags: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["gfortran", *flags, str(source)], capture_output=True, text=True, check=False)

class Lh096ContractTests(unittest.TestCase):
    def test_independent_three_case_behavioral_oracle(self) -> None:
        completed = subprocess.run([sys.executable, str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f")], capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_behavioral_cases: 3", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_fresh_tapenade_generation_and_fixed_form_gates(self) -> None:
        self.assertTrue(TAPENADE.is_file())
        manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
        for relative, expected in manifest["upstream_sha256"].items():
            self.assertEqual(hashlib.sha256((BENCH / "upstream/tapenade" / relative).read_bytes()).hexdigest(), expected, relative)
        for source_name in ("program.f", "program_p.f", "program_d.f", "program_b.f"):
            source = SOURCE_DIR / source_name
            self.assertEqual(compile_gate(source, STRICT_FIXED).returncode, 0, source_name)
            self.assertEqual(compile_gate(source, LEGACY_FIXED).returncode, 0, source_name)
        missing = SOURCE_DIR / "program_dv.f"
        for flags in (STRICT_FIXED, LEGACY_FIXED):
            refusal = compile_gate(missing, flags)
            self.assertNotEqual(refusal.returncode, 0)
            self.assertIn("DIFFSIZES.inc", refusal.stdout + refusal.stderr)
        with tempfile.TemporaryDirectory(prefix="lh096-tapenade-contract-") as temporary:
            root = Path(temporary)
            for mode, suffix in (("-p", "p"), ("-d", "d"), ("-b", "b")):
                output = root / suffix
                output.mkdir()
                generated = subprocess.run([str(TAPENADE), mode, "-root", "testliveness", "-O", str(output), "-o", "lh096", str(SOURCE_DIR / "program.f")], capture_output=True, text=True, check=False)
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                source = output / f"lh096_{suffix}.f"
                self.assertTrue(source.is_file())
                self.assertEqual(compile_gate(source, STRICT_FIXED).returncode, 0, suffix)
                self.assertEqual(compile_gate(source, LEGACY_FIXED).returncode, 0, suffix)

    def test_fortad_source_first_and_compatibility_contract(self) -> None:
        self.assertTrue(FORTAD.is_file())
        source = SOURCE_DIR / "program.f"
        with tempfile.TemporaryDirectory(prefix="lh096-fortad-contract-") as temporary:
            root = Path(temporary)
            checked = root / "checked.f90"
            check = subprocess.run([str(FORTAD), "check", "--proc", "testliveness", "--output", str(checked), str(source)], capture_output=True, text=True, check=False)
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            check_gate = compile_gate(checked, STRICT_FREE)
            self.assertNotEqual(check_gate.returncode, 0)
            self.assertIn("no IMPLICIT type", check_gate.stdout + check_gate.stderr)
            forward = root / "forward.f90"
            jvp = subprocess.run([str(FORTAD), "--mode", "forward", "--indep", "a", "--dep", "d", "--proc", "testliveness", "--name", "jvp", "--module", "m", "--output", str(forward), str(source)], capture_output=True, text=True, check=False)
            self.assertEqual(jvp.returncode, 0, jvp.stdout + jvp.stderr)
            self.assertEqual(compile_gate(forward, STRICT_FREE).returncode, 0)
            reverse = subprocess.run([str(FORTAD), "--mode", "reverse", "--indep", "a", "--dep", "d", "--proc", "testliveness", "--name", "vjp", "--module", "m", "--output", str(root / "reverse.f90"), str(source)], capture_output=True, text=True, check=False)
            self.assertNotEqual(reverse.returncode, 0)
            self.assertIn("assignment to undeclared 'sub1'", reverse.stdout + reverse.stderr)
            for mode, suffix in (("-p", "p"), ("-d", "d")):
                output = root / f"compat-{suffix}"
                output.mkdir()
                result = subprocess.run([str(FORTAD), mode, "-root", "testliveness", "-O", str(output), "-o", "lh096", str(source)], capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                generated = output / f"lh096_{suffix}.f90"
                self.assertTrue(generated.is_file())
                refusal = compile_gate(generated, STRICT_FREE)
                if mode == "-p":
                    self.assertNotEqual(refusal.returncode, 0)
                    self.assertIn("no IMPLICIT type", refusal.stdout + refusal.stderr)
                else:
                    self.assertEqual(refusal.returncode, 0)
            output = root / "compat-b"
            output.mkdir()
            result = subprocess.run([str(FORTAD), "-b", "-root", "testliveness", "-O", str(output), "-o", "lh096", str(source)], capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("could not infer Tapenade dependent", result.stdout + result.stderr)

if __name__ == "__main__":
    unittest.main()
