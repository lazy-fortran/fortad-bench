#!/usr/bin/env python3
"""Three independent checks for the bd11 exact-refusal boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade")))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "bd11"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


def result_hashes(report: str) -> dict[str, str]:
    in_block = False
    hashes: dict[str, str] = {}
    for line in report.splitlines():
        if line == "upstream_sha256:":
            in_block = True
            continue
        if line == "fresh_tapenade_sha256:":
            break
        if in_block:
            digest, name = line.split(maxsplit=1)
            hashes[name] = digest
    return hashes


class Bd11ContractTests(unittest.TestCase):
    def test_manifest_pins_upstream_and_source_checksums(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)

        self.assertEqual(manifest["classification"], "expected-refusal-with-bounded-array-section-port")
        self.assertEqual(manifest["source_form"], "free")
        self.assertEqual(manifest["upstream_entry_point"], "top(i1,i2,i3)")
        self.assertEqual(manifest["stored_references"], [])
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        expected = manifest["upstream_sha256"]
        actual = {name: sha256(SOURCE_DIR / name) for name in expected}
        self.assertEqual(actual, expected)
        self.assertEqual(result_hashes(RESULT.read_text()), expected)

    def test_independent_hand_finite_difference_and_adjoint_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertIn("finite_difference_max_error:", completed.stdout)
        self.assertIn("adjoint_identity_residual:", completed.stdout)

    def test_result_records_all_engine_boundaries(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-array-section-port",
            "upstream_exact_strict_compile: program.f90=0",
            "stored_references: none",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_parser: expected-refusal status=1",
            "fortad_exact_forward: expected-refusal status=1",
            "fortad_exact_reverse: expected-refusal status=1",
            "fortad_bounded_forward: transform=0 compile=0 runtime=pass",
            "fortad_bounded_reverse_objective: transform=0 compile=0 runtime=pass",
            "bounded_port_compile: port=0 hand=0 harness=0 link=0",
            "harness_status: pass",
            "oracle_status: pass",
            "unsupported array section at line 6: noncontiguous and overlapping storage identity is not tracked",
        ):
            self.assertIn(marker, report)

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
