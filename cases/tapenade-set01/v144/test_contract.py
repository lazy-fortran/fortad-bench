#!/usr/bin/env python3
"""Three-test independent contract for todoF90/REFERENCES/v144."""

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


def existing_path(env_name: str, *candidates: Path) -> Path:
    configured = os.environ.get(env_name)
    options = ([Path(configured)] if configured else []) + list(candidates)
    for candidate in options:
        if candidate.is_dir():
            return candidate
    raise AssertionError(f"no {env_name} checkout found: {options}")


UPSTREAM = existing_path(
    "TAPENADE_REPO",
    BENCH / "upstream" / "tapenade",
    Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"),
)
FORTAD = existing_path(
    "FORTAD_REPO",
    BENCH.parent / "fortad",
    Path("/mnt/storage/code/lazy-fortran/fortad"),
)
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v144"
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class V144ContractTests(unittest.TestCase):
    def test_manifest_pins_invalid_source_and_checksums(self) -> None:
        with MANIFEST.open("rb") as stream:
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
        self.assertEqual(manifest["upstream_entry_point"], "head(a,b,c,resu)")
        self.assertIn(
            "todoF90/REFERENCES/v144/program_d.f90",
            manifest["stored_references"],
        )
        self.assertEqual(
            sha256(SOURCE_DIR / "program.f90"),
            manifest["upstream_sha256"]["program.f90"],
        )
        self.assertIn("no bounded port", manifest["closure"])

    def test_independent_strict_compiler_oracle_rejects_all_sources(self) -> None:
        with tempfile.TemporaryDirectory(prefix="fortad-v144-contract-") as directory:
            output = Path(directory)
            for label, filename in (
                ("program", "program.f90"),
                ("stored_tangent", "program_d.f90"),
                ("stored_reverse", "program_b.f90"),
            ):
                (output / label).mkdir()
                completed = subprocess.run(
                    [
                        "gfortran",
                        *STRICT_FLAGS,
                        f"-I{SOURCE_DIR}",
                        f"-J{output / label}",
                        "-c",
                        str(SOURCE_DIR / filename),
                        "-o",
                        str(output / f"{label}.o"),
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                diagnostic = completed.stdout + completed.stderr
                self.assertNotEqual(completed.returncode, 0, label)
                if label == "program":
                    self.assertIn("Explicit interface required for", diagnostic)
                    self.assertIn("Rank mismatch in argument", diagnostic)
                else:
                    self.assertIn("Legacy Extension: REAL array index", diagnostic)

    def test_result_records_all_pinned_engine_boundaries(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_exact_strict_compile: program.f90=1 program_d.f90=1 program_b.f90=1",
            "tapenade_generation: parser=0 forward=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=1 forward=1 reverse=1",
            'fortad_exact_parser: expected-refusal status=1 output=none diagnostic="fortad: unsupported expression at line 10"',
            'fortad_exact_forward: expected-refusal status=1 output=none diagnostic="fortad: unsupported expression at line 10"',
            'fortad_exact_reverse: expected-refusal status=1 output=none diagnostic="fortad: unsupported expression at line 10"',
            "independent_oracle: pass-strict-gfortran-diagnostics-and-pinned-source-checksums",
            "port_result: not-applicable-invalid-upstream-source",
        ):
            self.assertIn(marker, report)

        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(FORTAD), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip(),
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )


if __name__ == "__main__":
    unittest.main(verbosity=1)
