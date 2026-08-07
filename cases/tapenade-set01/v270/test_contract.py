#!/usr/bin/env python3
"""Three-test source-boundary contract for Tapenade todoF90/REFERENCES/v270."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = Path(
    os.environ.get("TAPENADE_REPO", str(CASE.parents[2] / "upstream" / "tapenade"))
) / "todoF90" / "REFERENCES" / "v270"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"


class V270ContractTests(unittest.TestCase):
    def test_manifest_pins_invalid_source_and_checksums(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["source_form"], "free")
        self.assertEqual(manifest["upstream_entry_point"], "simtest1.solvereal(this,c)")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        for name, expected in manifest["upstream_sha256"].items():
            digest = hashlib.sha256((UPSTREAM / name).read_bytes()).hexdigest()
            self.assertEqual(digest, expected, name)

    def test_invalid_boundary_has_no_repair_port(self) -> None:
        source = (UPSTREAM / "program.f90").read_text(encoding="utf-8")
        self.assertIn("REAL*8", source)
        self.assertIn("INTEGER*4", source)
        report = RESULT.read_text(encoding="utf-8")
        self.assertIn(
            "port_result: not-applicable-no-standard-conforming-semantics-to-preserve",
            report,
        )
        self.assertIn("no numerical oracle for invalid source", report)

    def test_result_records_all_pinned_engine_boundaries(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_exact_strict_compile: program=1 diffsizes=0",
            "stored_strict_compile: program_d=1 program_dv=1",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=1 tangent=1 reverse=1",
            "fortad_exact_parser: expected-refusal status=1 output=none",
            "fortad_exact_forward: expected-refusal status=1 output=none",
            "fortad_exact_reverse: expected-refusal status=1 output=none",
            "GNU Extension: Nonstandard type declaration REAL*8",
            "fortad: unsupported allocation lifetime construct 'allocatable declaration/component' at line 6; active allocation state is not represented yet",
        ):
            self.assertIn(marker, report)
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM.parent.parent.parent), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )


if __name__ == "__main__":
    unittest.main(verbosity=1)
