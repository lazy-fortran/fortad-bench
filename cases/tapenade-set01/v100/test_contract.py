#!/usr/bin/env python3
"""Three-test behavioral contract for the pinned v100 case."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get(
        "TAPENADE_REPO", "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"
    )
)
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad")
)
SOURCE_DIR = UPSTREAM_ROOT / "todoF90" / "REFERENCES" / "v100"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"


class V100ContractTests(unittest.TestCase):
    def test_manifest_pins_bounded_semantics(self) -> None:
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
            manifest["classification"], "expected-refusal-with-bounded-forward-port"
        )
        self.assertEqual(manifest["upstream_entry_point"], "head(x,y)")
        self.assertIn("0.2 < x_in(1) < 0.4", manifest["ported_entry_point"])
        self.assertIn("MOD", manifest["closure"])

    def test_independent_behavioral_oracle(self) -> None:
        completed = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("finite_difference_max_error:", completed.stdout)
        self.assertIn("adjoint_identity_residual:", completed.stdout)
        self.assertIn("oracle_status: pass", completed.stdout)

    def test_result_and_pinned_source_contract(self) -> None:
        for name in (
            "program.f90",
            "program_Rd.f90",
            "program_Rb.f90",
            "program_Rd.msg",
            "program_Rb.msg",
            "Options",
        ):
            self.assertTrue((SOURCE_DIR / name).is_file(), name)
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-with-bounded-forward-port",
            "upstream_exact_strict_compile: primal=1 stored_tangent=0 stored_reverse=0",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_parser: transform=0 strict_compile=0 output=present",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "fortad_bounded_forward: transform=0 compile=0 runtime=pass",
            "fortad_bounded_reverse: transform=0 compile=0 runtime=pass",
            "harness_status: pass",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        self.assertTrue(FORTAD.is_file(), FORTAD)
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertIn(f"fortad_commit: {manifest['fortad_revision']}", report)
        self.assertIn(f"tapenade_commit: {manifest['upstream_revision']}", report)
        upstream_hashes = report.split("upstream_sha256:\n", 1)[1].split(
            "fresh_tapenade_sha256:", 1
        )[0]
        for name in (
            "program.f90",
            "program_Rd.f90",
            "program_Rb.f90",
            "program_Rd.msg",
            "program_Rb.msg",
            "Options",
        ):
            digest = hashlib.sha256((SOURCE_DIR / name).read_bytes()).hexdigest()
            self.assertIn(
                f"{digest}  todoF90/REFERENCES/v100/{name}", upstream_hashes
            )


if __name__ == "__main__":
    unittest.main()
