#!/usr/bin/env python3
"""Evidence-contract checks for the exact set02/lh193 dependency boundary."""

from __future__ import annotations

import csv
import hashlib
import json
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
).resolve()


class Lh193ContractTests(unittest.TestCase):
    def test_manifest_pins_exact_checkout_and_sources(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"], "blocked-missing-dependency")
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
        for relative, digest in manifest["upstream_sha256"].items():
            path = UPSTREAM_ROOT / relative
            self.assertTrue(path.is_file(), path)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest, relative)

    def test_exact_dependency_boundary_is_not_called_invalid(self) -> None:
        header = UPSTREAM_ROOT / "ADFirstAidKit/ampi/ampif.h"
        self.assertIn("include 'mpif.h'", header.read_text(encoding="utf-8"))
        self.assertFalse((UPSTREAM_ROOT / "ADFirstAidKit/mpich/include/mpif.h").exists())
        result = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: blocked-missing-dependency",
            "source_form: fixed",
            "upstream_exact_strict_compile: program=1 program_d=1",
            "upstream_exact_legacy_compile: program=1 program_d=1",
            "resolved_header_strict_compile: program=1 program_d=1",
            "resolved_header_legacy_compile: program=1 program_d=1",
            "Cannot open included file 'ampi/ampif.h'",
            "Cannot open included file 'mpif.h'",
            "dependency_inventory: ADFirstAidKit/ampi/ampif.h=present; ADFirstAidKit/mpich/include/mpif.h=absent",
            "tapenade_result: not-run-missing-dependency",
            "fortad_result: not-run-missing-dependency",
            "no_transformation_attempted: true",
            "not_invalid_upstream: true",
            "independent_oracle: not-applicable-transformation-not-reached",
        ):
            self.assertIn(marker, result)

    def test_automatic_compiler_inventory_records_the_same_boundary(self) -> None:
        compiler_rows = [
            json.loads(line)
            for line in (BENCH / "docs/corpora/tapenade-fortran-compiler.jsonl")
            .read_text(encoding="utf-8")
            .splitlines()
            if line
        ]
        compiler = next(
            row
            for row in compiler_rows
            if row["path"] == "nonRegressions/set02/lh193"
        )
        self.assertEqual(compiler["source_form_hint"], "fixed")
        self.assertEqual(compiler["compiler_version"], "GNU Fortran (GCC) 16.1.1 20260728")
        files = {file["path"]: file for file in compiler["files"]}
        for path, digest in {
            "nonRegressions/set02/lh193/program.f": "1b4dfc9f2e4cd76a1af41b318c03524981893037349cd607b3ccee1b515560c1",
            "nonRegressions/set02/lh193/program_d.f": "6adbdafd8d2546912bd87db905087863292b6869b6bd75d54122f4cb4c375548",
        }.items():
            self.assertEqual(files[path]["status"], "syntax-error")
            self.assertEqual(files[path]["failure_kind"], "missing-dependency")
            self.assertEqual(files[path]["diagnostic_hash"], digest)
        batch_rows = [
            json.loads(line)
            for line in (BENCH / "docs/corpora/tapenade-fortran-batch.jsonl")
            .read_text(encoding="utf-8")
            .splitlines()
            if line
        ]
        batch = next(row for row in batch_rows if row["path"] == "nonRegressions/set02/lh193")
        self.assertEqual(batch["candidate_status"], "compiler-missing-dependency")
        self.assertEqual(batch["next_action"], "resolve-dependency-or-record-refusal")

    def test_ledger_and_queue_close_only_lh193(self) -> None:
        with (BENCH / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        row = rows["nonRegressions/set02/lh193"]
        self.assertEqual(row["status"], "blocked-missing-dependency")
        self.assertEqual(row["entry_point"], "head(x,y)")
        self.assertEqual(row["tapenade_result"], "not-run-missing-dependency")
        self.assertEqual(row["fortad_result"], "not-run-missing-dependency")
        queue = (BENCH / "docs/corpora/tapenade-fortran-queue.jsonl").read_text()
        self.assertNotIn("nonRegressions/set02/lh193", queue)


if __name__ == "__main__":
    unittest.main()
