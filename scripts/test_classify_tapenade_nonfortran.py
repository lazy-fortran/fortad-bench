#!/usr/bin/env python3
"""Behavioral checks for deterministic non-Fortran ledger materialization."""

import unittest
from collections import Counter
from pathlib import Path

import classify_tapenade_nonfortran as classifier


def ledger_row(path: str, language: str, status: str = "untriaged") -> dict[str, str]:
    row = {
        "component": "fixture",
        "path": path,
        "language": language,
        "source_form_hint": "n/a" if language != "fortran" else "free",
        "initial_classification": "fixture candidates",
        "status": "untriaged",
        "entry_point": "untriaged",
        "tapenade_options": "untriaged",
        "modes": "untriaged",
        "oracle": "untriaged",
        "dependencies": "untriaged",
        "tapenade_result": "not-run",
        "fortad_result": "not-run",
    }
    if status != "untriaged":
        row.update({
            "status": status,
            "entry_point": "curated-entry",
            "tapenade_options": "none",
            "modes": "forward",
            "oracle": "hand",
            "dependencies": "none",
            "tapenade_result": "pass",
            "fortad_result": "pass",
        })
    return row


def triage_row(path: str, language: str) -> dict:
    classification = "non-fortran-source"
    if language == "unknown":
        classification = "harness-reference-data"
    if language == "fortran":
        classification = "fortran-procedure-candidate"
    if "|" in language:
        classification = "mixed-language-source"
    return {
        "classification": classification,
        "component": "fixture",
        "language": language,
        "path": path,
        "source_form_hint": "n/a" if language != "fortran" else "free",
    }


class MaterializationTests(unittest.TestCase):
    def test_materializes_only_pure_nonfortran_and_unknown_rows(self):
        languages = ["c", "c++", "cuda", "julia", "unknown", "fortran", "c|fortran"]
        ledger = [
            ledger_row(f"case-{language}", language) for language in languages
        ]
        ledger[5] = ledger_row("case-fortran", "fortran", "runnable-ported")
        triage = [
            triage_row(f"case-{language}", language) for language in languages
        ]

        actual, counts = classifier.materialize(ledger, triage)

        self.assertEqual(counts, Counter({language: 1 for language in languages[:5]}))
        for row in actual[:4]:
            self.assertEqual(
                {
                    field: row[field]
                    for field in classifier.UNSUPPORTED_LANGUAGE_FIELDS
                },
                classifier.UNSUPPORTED_LANGUAGE_FIELDS,
            )
        self.assertEqual(
            {field: actual[4][field] for field in classifier.UNKNOWN_SOURCE_FIELDS},
            classifier.UNKNOWN_SOURCE_FIELDS,
        )
        self.assertEqual(actual[5], ledger[5])
        self.assertEqual(actual[6], ledger[6])

    def test_refuses_to_replace_prior_target_evidence(self):
        ledger = [ledger_row("case-c", "c", "compiler-checked")]
        triage = [triage_row("case-c", "c")]

        with self.assertRaisesRegex(
            classifier.ClassificationError, "refusing to overwrite"
        ):
            classifier.materialize(ledger, triage)


class CommittedLedgerTests(unittest.TestCase):
    def test_committed_ledger_matches_static_materialization(self):
        root = Path(__file__).resolve().parent.parent
        ledger_path = root / "docs" / "corpora" / "tapenade-status.csv"
        triage_path = root / "docs" / "corpora" / "tapenade-static.jsonl"
        ledger = classifier.read_ledger(ledger_path)
        triage = classifier.read_triage(triage_path)

        expected, counts = classifier.materialize(ledger, triage)

        self.assertEqual(expected, ledger)
        self.assertEqual(
            counts,
            Counter({"c": 445, "c++": 16, "cuda": 35, "julia": 10, "unknown": 2}),
        )
        evidence_paths = {
            row["path"]
            for row in ledger
            if row["status"] not in {
                "untriaged",
                "fortad-unsupported-source-language",
                "no-recognized-source",
            }
        }
        self.assertEqual(evidence_paths, {
            "nonRegressions/set01/bd06",
            "nonRegressions/set01/lh001",
            "nonRegressions/set01/lh002",
            "nonRegressions/set01/lh019",
            "nonRegressions/set01/lh004",
            "nonRegressions/set01/lh023",
            "nonRegressions/set01/lh032",
            "nonRegressions/set01/lh049",
            "nonRegressions/set01/lh057",
            "nonRegressions/set01/lh058",
            "nonRegressions/set01/lh068",
            "nonRegressions/set01/lh066",
            "nonRegressions/set01/lh088",
            "nonRegressions/set01/lh134",
            "todoF90/REFERENCES/v420",
            "nonRegressions/set12/f03typf01",
            "ADFirstAidKit/testMemSizef.f",
            "ADFirstAidKit/validityTest.f",
        })
        self.assertEqual(
            sum(row["status"] == "untriaged" for row in ledger),
            1488,
        )


if __name__ == "__main__":
    unittest.main()
