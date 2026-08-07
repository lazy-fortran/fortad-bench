#!/usr/bin/env python3
"""Independent tests for the pure-Fortran evidence join."""

from __future__ import annotations

import json
import unittest

import batch_tapenade_fortran as batch


def queue_row(path: str, language: str = "fortran") -> dict:
    return {
        "component": "fixture",
        "path": path,
        "language": language,
        "queue_category": "runnable-procedure-candidate",
        "source_form_hint": "free",
        "source_files": [f"{path}/program.f90", f"{path}/helper.inc"],
    }


def compiler_row(path: str, statuses: list[tuple[str, str, str]]) -> dict:
    return {
        "component": "fixture",
        "path": path,
        "compiler": "gfortran",
        "compiler_version": "fixture compiler",
        "files": [
            {
                "path": source,
                "source_kind": "include-fragment" if source.endswith(".inc") else "free",
                "status": status,
                "failure_kind": failure,
                "diagnostic_hash": "0" * 64,
            }
            for source, status, failure in statuses
        ],
    }


def static_row(path: str, name: str | None) -> dict:
    return {
        "component": "fixture",
        "path": path,
        "entry_point_hints": [] if name is None else [
            {"kind": "subroutine", "name": name, "source": f"{path}/program.f90"},
            {"kind": "subroutine", "name": f"{name}_d", "source": f"{path}/program_d.f90"},
        ],
        "include_hints": [{"target": "helper.inc"}],
        "use_hints": [{"name": "fixture_mod"}],
    }


class BatchJoinTests(unittest.TestCase):
    def test_filters_mixed_language_and_joins_entry_points(self):
        pure = queue_row("fixture/pure")
        mixed = queue_row("fixture/mixed", "c|fortran")
        sources = [("fixture/pure/program.f90", "compiled", "none"),
                   ("fixture/pure/helper.inc", "include-fragment-not-compiled", "include-fragment")]
        rows = batch.build_batch(
            [mixed, pure],
            [compiler_row("fixture/pure", sources)],
            [static_row("fixture/pure", "step"), static_row("fixture/mixed", "mixed_step")],
        )
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["path"], "fixture/pure")
        self.assertTrue(rows[0]["pure_fortran"])
        self.assertEqual([hint["name"] for hint in rows[0]["entry_point_hints"]], ["step", "step_d"])
        self.assertEqual(rows[0]["candidate_status"], "compiler-clean")
        self.assertEqual(rows[0]["next_action"], "select-entry-point-and-probe")
        self.assertNotIn("support_status", json.dumps(rows[0]))

    def test_missing_dependency_is_not_mislabeled_support(self):
        row = queue_row("fixture/missing")
        files = [("fixture/missing/program.f90", "syntax-error", "missing-dependency"),
                 ("fixture/missing/helper.inc", "include-fragment-not-compiled", "include-fragment")]
        result = batch.build_batch([row], [compiler_row("fixture/missing", files)], [static_row("fixture/missing", "step")])[0]
        self.assertEqual(result["candidate_status"], "compiler-missing-dependency")
        self.assertEqual(result["next_action"], "resolve-dependency-or-record-refusal")
        self.assertNotIn("fortad_result", result)

    def test_missing_compiler_source_is_explicit(self):
        row = queue_row("fixture/incomplete")
        files = [("fixture/incomplete/program.f90", "compiled", "none")]
        result = batch.build_batch([row], [compiler_row("fixture/incomplete", files)], [static_row("fixture/incomplete", "step")])[0]
        self.assertEqual(result["candidate_status"], "compiler-report-incomplete")
        self.assertEqual(result["compiler_missing_source_files"], ["fixture/incomplete/helper.inc"])
        self.assertEqual(result["next_action"], "rerun-compiler-triage")

    def test_render_is_stable_for_input_order(self):
        rows = [queue_row("fixture/b"), queue_row("fixture/a")]
        reports = [compiler_row(row["path"], [(f"{row['path']}/program.f90", "compiled", "none"), (f"{row['path']}/helper.inc", "include-fragment-not-compiled", "include-fragment")]) for row in rows]
        static = [static_row("fixture/b", "b"), static_row("fixture/a", "a")]
        first = batch.build_batch(rows, reports, static)
        second = batch.build_batch(list(reversed(rows)), list(reversed(reports)), list(reversed(static)))
        self.assertEqual(batch.render(first), batch.render(second))

    def test_missing_candidate_report_fails_loudly(self):
        with self.assertRaises(batch.BatchError):
            batch.build_batch([queue_row("fixture/missing")], [], [static_row("fixture/missing", "step")])


if __name__ == "__main__":
    unittest.main()
