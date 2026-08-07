#!/usr/bin/env python3
"""Three-test contract for the pinned v05 invalid-source boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
DEFAULT_UPSTREAM = CASE.parents[2] / "upstream" / "tapenade"
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v05" / "program.f90"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


class V05ContractTests(unittest.TestCase):
    def test_manifest_pins_source_and_revisions(self) -> None:
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
        self.assertEqual(
            manifest["selected_entry_points"],
            [
                "RETARD(CK,I_ZONE,SP,TEMPS,IFIM1)",
                "COMP_PRECIPITATION(CK,DELTAT)",
            ],
        )
        self.assertTrue(SOURCE.is_file())
        self.assertEqual(
            manifest["upstream_sha256"]["todoF90/REFERENCES/v05/program.f90"],
            sha256(SOURCE),
        )
        report = RESULT.read_text(encoding="utf-8")
        self.assertIn("fortad_commit: b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a", report)
        self.assertIn(
            "tapenade_commit: e59864cab441d4175df75383b3ff58c3dcd26df9",
            report,
        )

    def test_exact_source_reproduces_invalid_compiler_diagnostic(self) -> None:
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn("FUNCTION RETARD(CK,I_ZONE,SP,TEMPS,IFIM1)", source)
        self.assertIn("RN = RETARD(CK(1,1),I_ZONE,SP)", source)
        self.assertIn("REAL(KIND=8):: CK,SORP,EPSI", source)

        completed = subprocess.run(
            [
                os.environ.get("FC", "gfortran"),
                "-std=f2018",
                "-ffree-form",
                "-ffree-line-length-none",
                "-fsyntax-only",
                "-pedantic-errors",
                "-Wall",
                "-Wextra",
                "-Wimplicit-interface",
                str(SOURCE),
            ],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("Return type mismatch of function", completed.stderr)

    def test_result_records_fresh_and_fortad_boundaries(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_exact_strict_compile: program.f90=1",
            "upstream_exact_legacy_compile: program.f90=1",
            "tapenade_generation: retard_parser=0 retard_tangent=0 retard_reverse=0 comp_precipitation_parser=0 comp_precipitation_tangent=0 comp_precipitation_reverse=0",
            "tapenade_fresh_strict_compile: retard_parser=1 retard_tangent=0 retard_reverse=0 comp_precipitation_parser=1 comp_precipitation_tangent=not-applicable-no-source comp_precipitation_reverse=not-applicable-no-source",
            "fortad_exact_parser: retard=transform-status-0-generated-strict-compile-1; comp_precipitation=refused-status-1",
            "fortad_exact_forward: retard=transform-status-0-generated-strict-compile-1; comp_precipitation=refused-status-1",
            "fortad_exact_reverse: retard=refused-status-1 diagnostic=\"fortad: assignment to undeclared RETARD\"; comp_precipitation=refused-status-1",
            "port_result: not-applicable-no-standard-conforming-semantics-to-preserve",
            "upstream_sha256:\n",
            "fresh_tapenade_sha256:\n",
        ):
            self.assertIn(marker, report)

        recorded_line = next(
            line
            for line in report.splitlines()
            if line.endswith("  todoF90/REFERENCES/v05/program.f90")
        )
        self.assertEqual(recorded_line.split()[0], sha256(SOURCE))
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )


if __name__ == "__main__":
    unittest.main(verbosity=1)
