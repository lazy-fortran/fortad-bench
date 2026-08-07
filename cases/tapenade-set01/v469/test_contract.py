#!/usr/bin/env python3
"""Exactly three behavioral contract tests for the pinned v469 case."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM = Path(
    os.environ.get(
        "TAPENADE_REPO", "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"
    )
)
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v469"


def report() -> str:
    return (CASE / "result.txt").read_text(encoding="utf-8")


class V469ContractTests(unittest.TestCase):
    def test_exact_upstream_and_stored_reference_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "runnable-ported-with-exact-source-refusal")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        revision = subprocess.run(
            ["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(revision.stdout.strip(), manifest["upstream_revision"], revision.stderr)
        for name, expected in manifest["upstream_sha256"].items():
            source = SOURCE_DIR / name
            self.assertTrue(source.is_file(), source)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), expected, name)
        text = report()
        self.assertIn("upstream_exact_strict_compile: program.f90=1 program_Rd.f90=0 program_Rb.f90=0", text)
        self.assertIn("exact_primal_diagnostic: nonconforming-tab-character-under-pedantic-errors", text)

    def test_fresh_tapenade_generation_and_strict_compilation(self) -> None:
        text = report()
        self.assertIn("tapenade_generation: parser=0 tangent=0 reverse=0", text)
        self.assertIn("tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0", text)
        self.assertIn("tapenade_fresh_sources: parser=v469_p.f90 tangent=v469_d.f90 reverse=v469_b.f90", text)

    def test_fortad_products_bounded_runtime_and_independent_oracle(self) -> None:
        text = report()
        self.assertIn("fortad_exact_parser: transform=0 strict_compile=0", text)
        self.assertIn("fortad_exact_forward: transform=0 strict_compile=0", text)
        self.assertIn("fortad_exact_reverse: transform=0 strict_compile=0", text)
        self.assertIn("fortad_bounded_forward: transform=0 strict_compile=0", text)
        self.assertIn("fortad_bounded_reverse: transform=0 strict_compile=0", text)
        self.assertIn("bounded_port_compile: port=0 harness=0 link=0 runtime=0", text)
        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_status: pass bounded_domain=one-element-finite-real", oracle.stdout)
        self.assertIn("harness_status: pass", text)


if __name__ == "__main__":
    unittest.main(verbosity=1)
