#!/usr/bin/env python3
"""Independent behavioral tests for compiler-backed Tapenade triage."""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

import triage_tapenade_fortran as triage


def queue_row(path: str, source_files: list[str]) -> dict:
    return {
        "component": "fixture",
        "path": path,
        "language": "fortran",
        "queue_category": "runnable-procedure-candidate",
        "source_form_hint": "free",
        "source_files": source_files,
    }


@unittest.skipUnless(shutil.which("gfortran"), "gfortran is required for compiler oracle tests")
class CompilerOracleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="fortad-triage-", dir="/var/tmp/ert")
        self.root = Path(self.temp.name)
        (self.root / "ok.f90").write_text(
            "subroutine ok(x)\n  real :: x\n  x = x + 1.0\nend subroutine ok\n",
            encoding="utf-8",
        )
        (self.root / "bad.f90").write_text(
            "subroutine bad(x)\n  real :: x\n  x =\nend subroutine bad\n",
            encoding="utf-8",
        )
        (self.root / "fragment.inc").write_text("integer :: helper\n", encoding="utf-8")
        self.rows = [
            queue_row("fixture/a", ["ok.f90", "fragment.inc", "driver.c"]),
            queue_row("fixture/b", ["bad.f90"]),
        ]

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_statuses_are_compiler_evidence_not_support_claims(self) -> None:
        report = triage.build_report(self.rows, "gfortran", self.root, 15.0, jobs=2)
        self.assertEqual([(row["component"], row["path"]) for row in report], [("fixture", "fixture/a"), ("fixture", "fixture/b")])
        files = {file["path"]: file for row in report for file in row["files"]}
        self.assertEqual(files["ok.f90"]["status"], "compiled")
        self.assertEqual(files["bad.f90"]["status"], "syntax-error")
        self.assertEqual(files["fragment.inc"]["status"], "include-fragment-not-compiled")
        self.assertEqual(report[0]["ignored_non_fortran_files"], ["driver.c"])
        self.assertNotIn("support", json.dumps(report).lower())
        self.assertRegex(files["bad.f90"]["diagnostic_hash"], r"^[0-9a-f]{64}$")

    def test_diagnostic_hash_is_independent_of_checkout_path(self) -> None:
        other = self.root / "copy"
        other.mkdir()
        for name in ("ok.f90", "bad.f90", "fragment.inc"):
            (other / name).write_bytes((self.root / name).read_bytes())
        first = triage.build_report(self.rows, "gfortran", self.root, 15.0, jobs=1)
        second = triage.build_report(self.rows, "gfortran", other, 15.0, jobs=1)
        first_hashes = [file["diagnostic_hash"] for row in first for file in row["files"]]
        second_hashes = [file["diagnostic_hash"] for row in second for file in row["files"]]
        self.assertEqual(first_hashes, second_hashes)

    def test_generated_module_files_cannot_change_a_repeat(self) -> None:
        (self.root / "module.f90").write_text(
            "module fixture_module\ncontains\nsubroutine module_step(x)\nreal :: x\nx = x + 1.0\nend subroutine module_step\nend module fixture_module\n",
            encoding="utf-8",
        )
        rows = [queue_row("fixture/module", ["module.f90"])]
        first = triage.build_report(rows, "gfortran", self.root, 15.0, jobs=1)
        second = triage.build_report(rows, "gfortran", self.root, 15.0, jobs=1)
        self.assertEqual(triage.render_report(first), triage.render_report(second))
        self.assertFalse(any(self.root.glob("*.mod")))

    def test_shards_merge_to_the_same_sorted_report(self) -> None:
        full = triage.build_report(self.rows, "gfortran", self.root, 15.0, jobs=1)
        shard_a = triage.build_report(self.rows, "gfortran", self.root, 15.0, jobs=2, shard_index=0, shard_count=2)
        shard_b = triage.build_report(self.rows, "gfortran", self.root, 15.0, jobs=2, shard_index=1, shard_count=2)
        self.assertEqual(triage.render_report(full), triage.render_report(sorted(shard_a + shard_b, key=lambda row: (row["component"], row["path"]))))

        shard_a_path = self.root / "shard-a.jsonl"
        shard_b_path = self.root / "shard-b.jsonl"
        shard_a_path.write_text(triage.render_report(shard_a), encoding="utf-8")
        shard_b_path.write_text(triage.render_report(shard_b), encoding="utf-8")
        merged = triage.merge_reports([shard_b_path, shard_a_path], self.rows)
        self.assertEqual(triage.render_report(full), triage.render_report(merged))

    def test_summary_is_independent_of_checkout_path(self) -> None:
        report = triage.build_report(self.rows, "gfortran", self.root, 15.0, jobs=1)
        first = triage.render_summary(report, queue_count=len(self.rows), compiler="gfortran", checkout=self.root)
        second = triage.render_summary(report, queue_count=len(self.rows), compiler="gfortran", checkout=self.root / "another-worktree")
        self.assertEqual(first, second)

    def test_check_rejects_a_missing_summary(self) -> None:
        report = triage.build_report(self.rows, "gfortran", self.root, 15.0, jobs=1)
        output = self.root / "report.jsonl"
        summary = self.root / "summary.md"
        queue = self.root / "queue.jsonl"
        queue.write_text("".join(json.dumps(row) + "\n" for row in self.rows), encoding="utf-8")
        output.write_text(triage.render_report(report), encoding="utf-8")
        self.assertEqual(
            triage.main([
                "--checkout", str(self.root),
                "--queue", str(queue),
                "--output", str(output),
                "--summary", str(summary),
                "--check",
            ]),
            2,
        )

    def test_missing_checkout_is_explicit(self) -> None:
        missing = self.root / "does-not-exist"
        report = triage.build_report(self.rows, "gfortran", missing, 15.0, jobs=1)
        statuses = {file["status"] for row in report for file in row["files"]}
        self.assertEqual(statuses, {"checkout-missing"})


class SourceKindTests(unittest.TestCase):
    def test_source_form_detection(self) -> None:
        self.assertEqual(triage._source_kind("x.f"), "fixed")
        self.assertEqual(triage._source_kind("x.F90"), "free")
        self.assertEqual(triage._source_kind("x.inc"), "include-fragment")
        self.assertEqual(triage._source_kind("x.c"), "not-fortran")


if __name__ == "__main__":
    unittest.main()
