#!/usr/bin/env python3
"""Behavioral checks for the evidence-neutral Tapenade Fortran queue."""

import json
import unittest
from collections import Counter
from pathlib import Path

import queue_tapenade_fortran as queue


def ledger_row(path: str, *, language: str = "fortran", component: str = "fixture", status: str = "untriaged"):
    return {
        "component": component,
        "path": path,
        "language": language,
        "source_form_hint": "free",
        "initial_classification": "fixture",
        "status": status,
        "entry_point": "untriaged",
        "tapenade_options": "untriaged",
        "modes": "untriaged",
        "oracle": "untriaged",
        "dependencies": "untriaged",
        "tapenade_result": "not-run",
        "fortad_result": "not-run",
    }


def static_row(path: str, *, language: str = "fortran", classification: str = "fortran-procedure-candidate", entries=(), files=None, includes=()):
    return {
        "component": "fixture",
        "path": path,
        "language": language,
        "source_form_hint": "free",
        "classification": classification,
        "source_files": files or [f"fixture/{path}/program.f90"],
        "entry_point_hints": [
            {"kind": kind, "name": name, "source": f"fixture/{path}/program.f90"}
            for kind, name in entries
        ],
        "include_hints": [
            {"source": f"fixture/{path}/program.f90", "target": target}
            for target in includes
        ],
        "use_hints": [],
    }


class QueueClassificationTests(unittest.TestCase):
    def test_category_precedence_is_conservative(self):
        cases = [
            (static_row("mixed", language="c|fortran", classification="mixed-language-source", entries=(("program", "main"),)), ledger_row("mixed", language="c|fortran"), "mixed-language-risk"),
            (static_row("failure", entries=(("program", "main"),)), ledger_row("failure", component="fortran-known-failures"), "parser-or-invalid-risk"),
            (static_row("reference", classification="fortran-source-candidate", entries=(), files=["fixture/reference/program_d.f90"]), ledger_row("reference"), "reference-only-evidence"),
            (static_row("unknown", classification="fortran-source-candidate"), ledger_row("unknown"), "no-entry-point-evidence"),
            (static_row("program", classification="fortran-runnable-candidate", entries=(("program", "main"),)), ledger_row("program"), "runnable-program-candidate"),
            (static_row("procedure", entries=(("subroutine", "step"),)), ledger_row("procedure"), "runnable-procedure-candidate"),
        ]
        for static, ledger, expected in cases:
            with self.subTest(path=static["path"]):
                self.assertEqual(queue.classify_row(static, ledger)["queue_category"], expected)

    def test_dependency_signal_is_an_include_risk_not_a_missing_claim(self):
        static = static_row("dep", entries=(("subroutine", "step"),), includes=("external.inc",))
        result = queue.classify_row(static, ledger_row("dep"))
        self.assertEqual(result["queue_category"], "runnable-procedure-candidate")
        self.assertTrue(result["dependency_risk"])
        self.assertEqual(result["unresolved_include_hints"], ["external.inc"])
        self.assertIn("include-target-not-local", result["risk_flags"])

    def test_curated_and_non_fortran_rows_are_not_queued(self):
        rows = [
            (static_row("curated", entries=(("subroutine", "step"),)), ledger_row("curated", status="runnable-ported")),
            (static_row("c", language="c", classification="non-fortran-source"), ledger_row("c", language="c")),
        ]
        self.assertEqual([queue.classify_row(static, ledger) for static, ledger in rows], [None, None])


class CommittedQueueTests(unittest.TestCase):
    def test_checked_in_queue_has_expected_partition(self):
        root = Path(__file__).resolve().parent.parent
        rows = [json.loads(line) for line in (root / "docs/corpora/tapenade-fortran-queue.jsonl").read_text().splitlines()]
        self.assertEqual(len(rows), 1473)
        self.assertEqual(
            Counter(row["queue_category"] for row in rows),
            Counter({
                "mixed-language-risk": 74,
                "parser-or-invalid-risk": 36,
                "no-entry-point-evidence": 20,
                "runnable-program-candidate": 318,
                "runnable-procedure-candidate": 1025,
            }),
        )
        self.assertEqual(sum(row["dependency_risk"] for row in rows), 168)
        self.assertEqual(
            sum("missing-dependency-risk" in row["risk_categories"] for row in rows),
            168,
        )

    def test_queue_is_reproducible_from_committed_inputs(self):
        root = Path(__file__).resolve().parent.parent
        expected = queue.render_queue(queue.build_queue(
            queue.read_ledger(root / "docs/corpora/tapenade-status.csv"),
            queue.read_triage(root / "docs/corpora/tapenade-static.jsonl"),
        ))
        actual = (root / "docs/corpora/tapenade-fortran-queue.jsonl").read_text()
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
