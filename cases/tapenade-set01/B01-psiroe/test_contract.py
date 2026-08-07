#!/usr/bin/env python3
"""Three behavioral contract tests for the exact pinned B01 boundary case."""

from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
SOURCE_DIR = BENCH / "upstream/tapenade/nonRegressions/set01/B01"
TAPENADE = BENCH / "upstream/tapenade/bin/tapenade"
FORTAD = Path("/home/ert/code/lazy-fortran/fortad/build/fo/bin/fortad")
SOURCE = SOURCE_DIR / "program.f"
STRICT = [
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fsyntax-only",
    "-fno-lto",
]
LEGACY = [
    "-std=legacy",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fsyntax-only",
    "-fno-lto",
]


def compile_gate(source: Path, flags: list[str], include_dirs: list[Path]) -> subprocess.CompletedProcess[str]:
    command = ["gfortran", *flags]
    for include_dir in include_dirs:
        command.extend(["-I", str(include_dir)])
    command.append(str(source))
    return subprocess.run(command, capture_output=True, text=True, check=False)


class B01PsiroeContract(unittest.TestCase):
    def test_exact_source_and_stored_references_have_distinct_language_gates(self) -> None:
        manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
        for relative, expected in manifest["upstream_sha256"].items():
            actual = hashlib.sha256((BENCH / "upstream/tapenade" / relative).read_bytes()).hexdigest()
            self.assertEqual(actual, expected, relative)

        exact_files = [SOURCE_DIR / "program.f", SOURCE_DIR / "program_d.f", SOURCE_DIR / "program_b.f"]
        for source in exact_files:
            strict = compile_gate(source, STRICT, [SOURCE_DIR])
            legacy = compile_gate(source, LEGACY, [SOURCE_DIR])
            self.assertEqual(strict.returncode, 1, source.name)
            self.assertEqual(legacy.returncode, 0, source.name)
            diagnostic = strict.stdout + strict.stderr
            self.assertRegex(diagnostic, r"REAL\s*\*\s*8", source.name)

    def test_fresh_pinned_tapenade_generation_and_gates(self) -> None:
        before = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
        expected = {"-p": "B01_p", "-d": "B01_d", "-b": "B01_b"}
        with tempfile.TemporaryDirectory(prefix="fortad-B01-psiroe-tapenade-") as temporary:
            root = Path(temporary)
            for mode, stem in expected.items():
                output = root / mode[1:]
                output.mkdir()
                generated = subprocess.run(
                    [str(TAPENADE), mode, "-root", "psiroe", "-O", str(output), "-o", "B01", str(SOURCE)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
                generated_source = output / f"{stem}.f"
                self.assertTrue(generated_source.is_file(), generated_source)
                self.assertTrue((output / f"{stem}.msg").is_file(), stem)
                strict = compile_gate(generated_source, STRICT, [output, SOURCE_DIR])
                legacy = compile_gate(generated_source, LEGACY, [output, SOURCE_DIR])
                self.assertEqual(strict.returncode, 1, stem)
                self.assertEqual(legacy.returncode, 0, stem)
                self.assertRegex(strict.stdout + strict.stderr, r"REAL\s*\*\s*8", stem)
        self.assertEqual(hashlib.sha256(SOURCE.read_bytes()).hexdigest(), before)

    def test_fortad_refuses_all_modes_and_independent_geometry_oracle_passes(self) -> None:
        expected_status = {"-p": 1, "-d": 2, "-b": 2}
        with tempfile.TemporaryDirectory(prefix="fortad-B01-psiroe-fortad-") as temporary:
            root = Path(temporary)
            for mode, status in expected_status.items():
                output = root / mode[1:]
                output.mkdir()
                refusal = subprocess.run(
                    [str(FORTAD), mode, "-root", "psiroe", "-O", str(output), "-o", "B01", str(SOURCE)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(refusal.returncode, status, mode)
                self.assertIn("could not locate the end of this do construct", refusal.stdout + refusal.stderr)
                self.assertFalse(any(path.is_file() for path in output.rglob("*")), mode)

        oracle = subprocess.run(
            [sys.executable, str(CASE / "oracle.py"), str(SOURCE)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_behavioral_cases: 3", oracle.stdout)
        self.assertIn("oracle_status: pass", oracle.stdout)


if __name__ == "__main__":
    unittest.main()
