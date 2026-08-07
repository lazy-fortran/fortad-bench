#!/usr/bin/env python3
"""Behavioral and checksum contract checks for the lh076 evidence."""

from __future__ import annotations

import hashlib
import os
import re
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
default_upstream = CASE.parents[2] / "upstream" / "tapenade"
if not default_upstream.is_dir():
    default_upstream = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM_ROOT = Path(os.environ.get("TAPENADE_REPO", str(default_upstream)))
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh076"


def recorded_hashes(report: str, heading: str) -> dict[str, str]:
    section = report.split(heading + "\n", 1)[1]
    hashes: dict[str, str] = {}
    for line in section.splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            break
        hashes[match.group(2)] = match.group(1)
    return hashes


class Lh076ContractTests(unittest.TestCase):
    def test_manifest_pins_refusal_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
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
            "expected-refusal-with-bounded-forward-port",
        )
        self.assertEqual(manifest["upstream_entry_point"], "onegvert(pin4,emipint)")
        self.assertIn("DIFFSIZES.inc", manifest["dependencies"])
        self.assertIn("not reverse support", manifest["closure"])

    def test_independent_oracle_is_behavioral(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        for marker in (
            "numeric_hand_jvp: pass",
            "finite_difference: pass",
            "adjoint_identity: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, completed.stdout)

    def test_result_and_checksums_are_current(self) -> None:
        for name in (
            "program.f",
            "program_p.f",
            "program_d.f",
            "program_b.f",
            "program_dv.f",
            "program_p.msg",
            "program_d.msg",
            "program_b.msg",
            "program_dv.msg",
        ):
            self.assertTrue((UPSTREAM / name).is_file(), name)
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "upstream_exact_strict_compile: primal=1 parser=1 tangent=1 reverse=1 multidirectional=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=1 tangent=1 reverse=1",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward: pass-transform-compile-runtime",
            "fortad_bounded_reverse: expected-refusal",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)

        upstream_hashes = recorded_hashes(report, "upstream_sha256:")
        for name in (
            "program.f",
            "program_p.f",
            "program_d.f",
            "program_b.f",
            "program_dv.f",
            "program_p.msg",
            "program_d.msg",
            "program_b.msg",
            "program_dv.msg",
        ):
            expected = hashlib.sha256((UPSTREAM / name).read_bytes()).hexdigest()
            self.assertEqual(upstream_hashes.get(name), expected, name)

        artifact_hashes = recorded_hashes(report, "case_artifact_sha256:")
        for name in (
            "manifest.toml",
            "notes.md",
            "port.f90",
            "hand.f90",
            "harness.f90",
            "oracle.py",
            "run.sh",
            "test_contract.py",
        ):
            expected = hashlib.sha256((CASE / name).read_bytes()).hexdigest()
            self.assertEqual(artifact_hashes.get(name), expected, name)


if __name__ == "__main__":
    unittest.main()
