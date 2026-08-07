#!/usr/bin/env python3
"""Behavioral and checksum-contract checks for the bd01 case."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
DEFAULT_UPSTREAM_ROOT = CASE.parents[2] / "upstream" / "tapenade"
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM_ROOT)))
if "TAPENADE_REPO" not in os.environ and not UPSTREAM_ROOT.is_dir():
    installed_upstream = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
    if installed_upstream.is_dir():
        UPSTREAM_ROOT = installed_upstream
UPSTREAM = UPSTREAM_ROOT / "todoF90" / "REFERENCES" / "bd01"


def load_manifest() -> dict:
    with (CASE / "manifest.toml").open("rb") as stream:
        return tomllib.load(stream)


class Bd01ContractTests(unittest.TestCase):
    def test_manifest_pins_exact_and_bounded_boundaries(self) -> None:
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
            manifest["classification"],
            "expected-refusal-with-bounded-module-call-specialization",
        )
        self.assertEqual(
            manifest["upstream_entry_points"], ["titi(a,b,c)", "toto(a,b,c)"]
        )
        self.assertIn("todoF90/REFERENCES/bd01/program.f90", manifest["upstream_sources"])
        self.assertIn("cases/tapenade-set01/bd01/oracle.py", manifest["bounded_sources"])

    def test_independent_oracle_is_behavioral(self) -> None:
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

    def test_result_records_full_boundary_and_source_checksums(self) -> None:
        manifest = load_manifest()
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-module-call-specialization",
            "fortad_commit: b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
            "upstream_exact_strict_compile: tata=0 program=0",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_titi_forward: expected-refusal status=1 output=none",
            "fortad_exact_titi_reverse: expected-refusal status=1 output=none",
            "fortad_exact_toto_forward: transform=0 compile=0",
            "fortad_exact_toto_reverse: transform=0 compile=0",
            "fortad_bounded_forward: transform=0 compile=0",
            "fortad_bounded_reverse: transform=0 compile=0",
            "bounded_port_compile: port=0 hand=0 harness=0 link=0 runtime=0",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)

        recorded: dict[str, str] = {}
        in_hash_block = False
        for line in report.splitlines():
            if line == "upstream_sha256:":
                in_hash_block = True
                continue
            if line == "fresh_tapenade_sha256:":
                break
            if in_hash_block and line.strip():
                digest, path = line.split(maxsplit=1)
                recorded[path] = digest

        expected = {
            relative: hashlib.sha256((UPSTREAM_ROOT / relative).read_bytes()).hexdigest()
            for relative in (
                "todoF90/REFERENCES/bd01/Options",
                "todoF90/REFERENCES/bd01/program.f90",
                "todoF90/REFERENCES/bd01/tata.f90",
            )
        }
        self.assertEqual(recorded, expected)
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
