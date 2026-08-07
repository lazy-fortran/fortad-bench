#!/usr/bin/env python3
"""Three-test source-boundary contract for Tapenade todoF90/REFERENCES/v322."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
)
if not UPSTREAM_ROOT.is_dir() and Path(
    "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"
).is_dir():
    UPSTREAM_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad"))
)
if not FORTAD_ROOT.is_dir() and Path("/mnt/storage/code/lazy-fortran/fortad").is_dir():
    FORTAD_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad")
SOURCE_DIR = UPSTREAM_ROOT / "todoF90" / "REFERENCES" / "v322"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"


class V322ContractTests(unittest.TestCase):
    def test_manifest_pins_invalid_source_and_checksums(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
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
        self.assertEqual(
            manifest["upstream_entry_point"],
            "solvereal(this,c); private qcalc(this,Cmob)",
        )
        for name in (
            "DIFFSIZES.f90",
            "Options",
            "program.f90",
            "program_b.f90",
            "program_b.msg",
            "simtest1.mod",
        ):
            self.assertTrue((SOURCE_DIR / name).is_file(), name)

    def test_independent_strict_compiler_oracle(self) -> None:
        strict_flags = [
            "-std=f2018",
            "-ffree-form",
            "-ffree-line-length-none",
            "-pedantic-errors",
            "-Wall",
            "-Wextra",
            "-Wimplicit-interface",
            "-cpp",
            f"-I{SOURCE_DIR}",
            "-fsyntax-only",
        ]
        completed = subprocess.run(
            ["gfortran", *strict_flags, str(SOURCE_DIR / "program.f90")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("Nonstandard type declaration REAL*8", completed.stderr)
        self.assertEqual(
            subprocess.run(
                ["gfortran", *strict_flags, str(SOURCE_DIR / "DIFFSIZES.f90")],
                capture_output=True,
                check=False,
            ).returncode,
            0,
        )

    def test_result_records_pinned_engine_boundaries(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_exact_strict_compile: DIFFSIZES.f90=0 program.f90=1 program_b.f90=1",
            "upstream_legacy_compile: program.f90=0 program_b.f90=1",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_outputs: parser=v322_p.f90 tangent=v322_d.f90 reverse=v322_b.f90",
            "tapenade_fresh_strict_compile: parser=1 tangent=1 reverse=1",
            "fortad_exact_parser: expected-refusal status=1 output=none",
            "fortad_exact_forward: expected-refusal status=1 output=none",
            "fortad_exact_reverse: expected-refusal status=1 output=none",
            "bounded_port: not-claimed",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        self.assertIn(
            "fortad: unsupported allocation lifetime construct 'allocatable declaration/component' at line 6",
            report,
        )
        self.assertTrue(FORTAD.is_file(), FORTAD)
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        hashes = report.split("upstream_sha256:\n", 1)[1].split(
            "fresh_tapenade_sha256:", 1
        )[0]
        for name in (
            "DIFFSIZES.f90",
            "Options",
            "program.f90",
            "program_b.f90",
            "program_b.msg",
            "simtest1.mod",
        ):
            digest = hashlib.sha256((SOURCE_DIR / name).read_bytes()).hexdigest()
            self.assertIn(f"{digest}  {name}", hashes)


if __name__ == "__main__":
    unittest.main(verbosity=1)
