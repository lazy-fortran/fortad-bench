#!/usr/bin/env python3
"""Evidence-contract checks for the exact B04 invalid-upstream boundary."""

from __future__ import annotations

import csv
import hashlib
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[1]
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
).resolve()


class B04ContractTests(unittest.TestCase):
    def test_manifest_pins_exact_sources_and_invalid_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "unsupported-invalid-upstream-fortran")
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["upstream_tree"], "17288bdf7e03cb23b82ddc769d884deed9c9575e")
        self.assertEqual(manifest["fortad_revision"], "e13b43ad934e88e6fdf058646047003e4b385170")
        self.assertEqual(manifest["source_form"], "fixed")
        self.assertEqual(
            subprocess.check_output(
                ["git", "-C", str(UPSTREAM_ROOT), "remote", "get-url", "origin"],
                text=True,
            ).strip(),
            manifest["upstream_origin"],
        )
        self.assertEqual(
            subprocess.check_output(
                ["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD"],
                text=True,
            ).strip(),
            manifest["upstream_revision"],
        )
        self.assertEqual(
            subprocess.check_output(
                ["git", "-C", str(UPSTREAM_ROOT), "rev-parse", "HEAD^{tree}"],
                text=True,
            ).strip(),
            manifest["upstream_tree"],
        )
        self.assertFalse((UPSTREAM_ROOT / "examples/big01/B04/DIFFSIZES.inc").exists())
        for relative, digest in manifest["upstream_sha256"].items():
            path = UPSTREAM_ROOT / relative
            self.assertTrue(path.is_file(), path)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest, relative)

    def test_result_records_exact_compiler_engine_and_fortad_boundaries(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: unsupported-invalid-upstream-fortran",
            "upstream_exact_strict_compile: program.f=1 program_p.f=1 program_d.f=1 program_dv.f=1",
            "upstream_exact_legacy_compile: program.f=1 program_p.f=1 program_d.f=1 program_dv.f=1",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_compile_strict: parser=1 tangent=0 reverse=1",
            "tapenade_fresh_compile_legacy: parser=1 tangent=0 reverse=1",
            "fortad_exact_parser: expected-refusal",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "invalid-character-line-20599",
            "independent_oracle: not-applicable-invalid-upstream-no-support-claim",
            "no_repaired_source: true",
        ):
            self.assertIn(marker, report)

    def test_ledger_and_queue_close_only_b04(self) -> None:
        with (BENCH / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["examples/big01/B04"]
        self.assertEqual(row["status"], "unsupported-invalid-upstream-fortran")
        self.assertEqual(row["entry_point"], "MOFDER_GEAR(NEQ,T,Y,YDOT)")
        self.assertEqual(
            row["tapenade_result"],
            "pass-fresh-parser-tangent-reverse-generation-invalid-source-and-missing-diffsizes-boundary",
        )
        self.assertEqual(
            row["fortad_result"],
            "expected-refusal-exact-parse-invalid-character-line-20599-no-output",
        )
        queue = (BENCH / "docs/corpora/tapenade-fortran-queue.jsonl").read_text()
        self.assertNotIn('"path":"examples/big01/B04"', queue)


if __name__ == "__main__":
    unittest.main()
