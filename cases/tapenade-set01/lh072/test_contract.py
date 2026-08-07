#!/usr/bin/env python3
"""Behavioral and checksum-contract checks for the lh072 case."""

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
UPSTREAM = UPSTREAM_ROOT / "nonRegressions" / "set01" / "lh072"


class Lh072ContractTests(unittest.TestCase):
    def test_manifest_pins_sources_and_bounded_boundary(self) -> None:
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
            "expected-refusal-with-bounded-callback-specialization",
        )
        self.assertEqual(
            manifest["upstream_entry_point"], "top(A,B); extf(B(10))"
        )
        self.assertIn(
            "nonRegressions/set01/lh072/program_dv.f",
            manifest["upstream_sources"],
        )
        self.assertIn(
            "cases/tapenade-set01/lh072/oracle.py",
            manifest["bounded_sources"],
        )

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
        self.assertIn("callback_b4:", completed.stdout)

    def test_result_contract_and_upstream_checksums(self) -> None:
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
            "classification: expected-refusal-with-bounded-callback-specialization",
            "fortad_commit: b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
            "upstream_exact_strict_compile: primal=0 parser=0 tangent=0 reverse=0 multidirectional=1",
            "tapenade_generation: parser=pass tangent=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_forward: expected-refusal status=1",
            "fortad_exact_reverse: expected-refusal status=1",
            "fortad_bounded_forward: transform=0 compile=0",
            "fortad_bounded_reverse_a_sum: transform=0 compile=0",
            "bounded_port_compile: port=0 hand=0 harness=0",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)

        in_hash_block = False
        recorded: dict[str, str] = {}
        for line in report.splitlines():
            if line == "upstream_sha256:":
                in_hash_block = True
                continue
            if line == "fresh_tapenade_sha256:":
                break
            if in_hash_block:
                digest, name = line.split(maxsplit=1)
                recorded[name] = digest

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
            self.assertEqual(recorded.get(name), expected, name)


if __name__ == "__main__":
    unittest.main()
