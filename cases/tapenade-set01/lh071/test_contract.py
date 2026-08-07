#!/usr/bin/env python3
"""Behavioral/checksum contract checks for the invalid-upstream lh071 case."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(CASE.parents[2] / "upstream" / "tapenade"))
)


def load_manifest() -> dict:
    with (CASE / "manifest.toml").open("rb") as stream:
        return tomllib.load(stream)


class Lh071ContractTests(unittest.TestCase):
    def test_manifest_pins_both_exact_entry_points(self) -> None:
        manifest = load_manifest()
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(
            manifest["classification"], "expected-refusal-invalid-upstream"
        )
        self.assertEqual(
            manifest["selected_entry_points"],
            ["set01/lh071:adj(a,b,c,d)", "set03/lh071:nonadjdeadtest(x,y)"],
        )
        self.assertEqual(len(manifest["upstream_sources"]), 6)

    def test_result_is_a_checksum_and_diagnostic_oracle(self) -> None:
        manifest = load_manifest()
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        self.assertIn("upstream_sha256:\n", report)
        self.assertIn("fortad_commit: b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a", report)

        recorded: dict[str, str] = {}
        in_block = False
        for line in report.splitlines():
            if line == "upstream_sha256:":
                in_block = True
                continue
            if line == "fresh_tapenade_sha256:":
                in_block = False
            if in_block and line.strip():
                digest, path = line.split(maxsplit=1)
                recorded[path.strip()] = digest

        expected: dict[str, str] = {}
        for relative in manifest["upstream_sources"]:
            path = UPSTREAM_ROOT / relative
            self.assertTrue(path.is_file(), relative)
            expected[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.assertEqual(recorded, expected)

    def test_result_records_the_full_refusal_contract(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_exact_strict_compile: set01_program=1 set01_program_b=1 set03_program=1 set03_program_b=1",
            "upstream_stored_reference_strict_compile: set01_program_b=1 set03_program_b=1",
            "tapenade_generation: set01_parser=0 set01_tangent=0 set01_reverse=0 set03_parser=0 set03_tangent=0 set03_reverse=0",
            "tapenade_fresh_strict_compile: set01_parser=1 set01_tangent=1 set01_reverse=1 set03_parser=1 set03_tangent=1 set03_reverse=1",
            'fortad_exact_forward: set01=expected-refusal status=1 output=none diagnostic="unsupported statement at line 4"; set03=expected-refusal status=1 output=none diagnostic="unsupported aliasing declaration p at line 8"',
            'fortad_exact_reverse: set01=expected-refusal status=1 output=none diagnostic="unsupported statement at line 4"; set03=expected-refusal status=1 output=none diagnostic="unsupported aliasing declaration p at line 8"',
            "bounded_port: not-claimed",
        ):
            self.assertIn(marker, report)

        # The runner is required to leave a generated record, not merely a
        # manifest-shaped placeholder.
        self.assertGreater(report.count("upstream_sha256:"), 0)
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )


if __name__ == "__main__":
    unittest.main()
