#!/usr/bin/env python3
"""Three-test source-boundary contract for Tapenade todoF90/REFERENCES/v07."""

from __future__ import annotations

import hashlib
import os
import re
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = Path(
    os.environ.get("TAPENADE_REPO", str(CASE.parents[2] / "upstream" / "tapenade"))
)
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v07" / "program.f90"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def result_hashes(report: str, start_marker: str, end_marker: str) -> dict[str, str]:
    start = report.index(start_marker) + len(start_marker)
    end = report.index(end_marker, start)
    hashes: dict[str, str] = {}
    for line in report[start:end].splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (\S+)", line)
        if match:
            hashes[match.group(2)] = match.group(1)
    return hashes


class V07ContractTests(unittest.TestCase):
    def test_manifest_pins_invalid_source_and_checksum(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)

        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["source_form"], "free")
        self.assertEqual(manifest["static_entry_point_hints"], [])
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["upstream_sha256"]["program.f90"],
            "e0894c6910a66811ce733a526fead85844e2aad6c0f5d2216bd5811b4589dda7",
        )
        self.assertEqual(sha256(SOURCE), manifest["upstream_sha256"]["program.f90"])

    def test_source_boundary_is_observable_without_a_repair(self) -> None:
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn("implicit none", source.lower())
        self.assertIn("public :: foo", source.lower())
        self.assertNotRegex(source.lower(), r"\b(program|subroutine|function)\b")

        report = RESULT.read_text(encoding="utf-8")
        self.assertIn("has no IMPLICIT type", report)
        self.assertIn("no-top-procedure-and-undeclared-foo", report)
        self.assertIn("port_result: not-applicable-no-standard-conforming-semantics-to-preserve", report)

    def test_result_records_all_pinned_engine_boundaries(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_exact_strict_compile: program.f90=1",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_outputs: parser=v07_parser_p.f90 tangent=none reverse=none",
            "tapenade_fresh_strict_compile: parser=1 tangent=not-applicable-no-source reverse=not-applicable-no-source",
            'fortad_exact_parser: expected-refusal status=1 output=none diagnostic="fortad: no function or subroutine found in source"',
            'fortad_exact_forward: expected-refusal status=1 output=none diagnostic="fortad: no procedure named foo in this source"',
            'fortad_exact_reverse: expected-refusal status=1 output=none diagnostic="fortad: no procedure named foo in this source"',
        ):
            self.assertIn(marker, report)

        recorded = result_hashes(report, "upstream_sha256:\n", "fresh_tapenade_sha256:")
        self.assertEqual(recorded, {"program.f90": sha256(SOURCE)})
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )


if __name__ == "__main__":
    unittest.main(verbosity=1)
