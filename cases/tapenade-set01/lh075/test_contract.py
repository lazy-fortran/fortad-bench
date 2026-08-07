#!/usr/bin/env python3
"""Behavioral and checksum contract for the lh075 source-boundary evidence."""

from __future__ import annotations

import hashlib
import os
import re
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
DEFAULT_UPSTREAM = CASE.parents[2] / "upstream" / "tapenade"
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
if not UPSTREAM.is_dir() and "TAPENADE_REPO" not in os.environ:
    common_git_dir = subprocess.run(
        ["git", "-C", str(CASE.parents[2]), "rev-parse", "--git-common-dir"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    shared_root = Path(common_git_dir).resolve().parent
    fallback = shared_root / "upstream" / "tapenade"
    if fallback.is_dir():
        UPSTREAM = fallback
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set01" / "lh075"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


def result_hashes(report: str, section: str, next_section: str) -> dict[str, str]:
    start = report.index(section) + len(section)
    end = report.index(next_section, start)
    hashes: dict[str, str] = {}
    for line in report[start:end].splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (\S+)", line)
        if match:
            hashes[match.group(2)] = match.group(1)
    return hashes


class Lh075ContractTests(unittest.TestCase):
    def test_manifest_and_upstream_checksums(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)

        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["source_form"], "fixed")
        self.assertEqual(manifest["upstream_entry_point"], "phi(PHIS,s1)")
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )

        expected = manifest["upstream_sha256"]
        actual = {name: sha256(SOURCE_DIR / name) for name in expected}
        self.assertEqual(actual, expected)

        report = RESULT.read_text(encoding="utf-8")
        recorded = result_hashes(report, "upstream_sha256:\n", "fresh_tapenade_sha256:")
        self.assertEqual(recorded, expected)

    def test_fixed_source_boundary_is_observable(self) -> None:
        primal = (SOURCE_DIR / "program.f").read_text(encoding="utf-8")
        stored_parser = (SOURCE_DIR / "program_p.f").read_text(encoding="utf-8")
        self.assertIn("subroutine phi(phis,s1)", primal.lower())
        self.assertIn("PHI(N1)", primal)
        self.assertIn("PHI(N2)", primal)
        self.assertNotIn("function phi", primal.lower())
        self.assertIn("Unexpected use of subroutine name", (CASE / "result.txt").read_text())
        self.assertIn("PHI(n1)", stored_parser)
        for message in ("program_p.msg", "program_d.msg", "program_b.msg", "program_dv.msg"):
            self.assertIn("TC35", (SOURCE_DIR / message).read_text(encoding="utf-8"))

    def test_result_records_all_engine_boundaries(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_exact_strict_compile: program.f=1 program_p.f=1",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_outputs: parser=lh075_p.f tangent=none reverse=none",
            "tapenade_fresh_strict_compile: parser=1 tangent=not-applicable-no-source reverse=not-applicable-no-source",
            "fortad_exact_forward: expected-refusal status=1 diagnostic=\"fortad: unsupported statement at line 3\"",
            "fortad_exact_reverse: expected-refusal status=1 diagnostic=\"fortad: unsupported statement at line 3\"",
            "port_result: not-applicable-no-standard-conforming-semantics-to-preserve",
        ):
            self.assertIn(marker, report)

        self.assertEqual(
            re.search(r"^fortad_commit: (\S+)$", report, re.MULTILINE).group(1),
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
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
