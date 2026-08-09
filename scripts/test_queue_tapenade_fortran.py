#!/usr/bin/env python3
"""Behavioral checks for the evidence-neutral Tapenade Fortran queue."""

import json
import unittest
from collections import Counter
from pathlib import Path

import queue_tapenade_fortran as queue


MEASURED_SHARD_CLOSURES = {
    ("non-regressions", "nonRegressions/set10/v297"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set11/vpf06"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set05/v173"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set04/lh150"): "unsupported-fortad-allocatable-lifetime",
    ("non-regressions", "nonRegressions/set10/lh215"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set10/lh216"): "unsupported-fortad-generic-intrinsic",
    ("non-regressions", "nonRegressions/set12/mvo11"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set07/v472"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set05/v182"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set07/v499"): "unsupported-fortad-active-io",
    ("non-regressions", "nonRegressions/set10/lh233"): "unsupported-fortad-program-unit-layout",
    ("non-regressions", "nonRegressions/set11/vpf23"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set03/cm05"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/cm10"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/cm34"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set03/lh013"): "runnable-ported",
    ("non-regressions", "nonRegressions/set01/B05"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set01/bd07"): "unsupported-fortad-active-io",
    ("non-regressions", "nonRegressions/set01/ht01"): "unsupported-fortad-character-section",
    ("non-regressions", "nonRegressions/set01/lh043"): "unsupported-fortad-legacy-labeled-do",
    ("non-regressions", "nonRegressions/set01/lh099"): "unsupported-fortad-do-while",
    ("non-regressions", "nonRegressions/set01/lh101"): "unsupported-invalid-upstream-fortran",
    ("non-regressions", "nonRegressions/set01/lh106"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set01/lh108"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set01/lh110"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set01/lh111"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set01/lh112"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set01/lh113"): "unsupported-invalid-upstream-fortran",
    ("non-regressions", "nonRegressions/set01/lh114"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set01/lh115"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set01/lh117"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set01/lh118"): "unsupported-fortad-active-io",
    ("non-regressions", "nonRegressions/set01/lh119"): "unsupported-fortad-active-io",
    ("non-regressions", "nonRegressions/set01/lh120"): "unsupported-fortad-legacy-goto",
    ("non-regressions", "nonRegressions/set01/lh121"): "unsupported-fortad-do-while",
    ("non-regressions", "nonRegressions/set01/lh122"): "unsupported-fortad-legacy-labeled-do",
    ("non-regressions", "nonRegressions/set01/lh123"): "unsupported-fortad-reverse-loop-control",
    ("non-regressions", "nonRegressions/set01/lh124"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set01/lh125"): "unsupported-fortad-implicit-typing",
    ("non-regressions", "nonRegressions/set01/lh126"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set04/v035"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set03/cm35"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/cmv01"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set06/v307"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set07/v398"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set07/v529"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set04/lh142"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set11/vpf21"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set06/v346"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set07/v397"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set11/vpf15"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set03/cm23"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set06/v335"): "unsupported-fortad-no-independent-variable",
    ("non-regressions", "nonRegressions/set06/v342"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set11/vpf09"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set12/mvo33"): "unsupported-fortad-procedure-pointer-callback",
    ("non-regressions", "nonRegressions/set04/lh109"): "unsupported-fortad-derived-component-allocation",
    ("non-regressions", "nonRegressions/set04/lh121"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set04/lh159"): "unsupported-fortad-allocatable-derived-component",
    ("non-regressions", "nonRegressions/set05/v196"): "unsupported-fortad-no-int-derivative-rule",
    ("non-regressions", "nonRegressions/set05/v202"): "unsupported-fortad-elemental-parse",
    ("non-regressions", "nonRegressions/set05/v193"): "unsupported-fortad-derived-pointer-replay",
    ("non-regressions", "nonRegressions/set06/v220"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set06/v232"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set11/vmp06"): "unsupported-fortad-pointer-ownership",
    ("non-regressions", "nonRegressions/set11/vmp07"): "unsupported-fortad-active-io",
    ("non-regressions", "nonRegressions/set04/ptr07"): "unsupported-fortad-recursive-pointer-ownership",
    ("non-regressions", "nonRegressions/set04/ptr08"): "unsupported-fortad-recursive-pointer-ownership",
    ("non-regressions", "nonRegressions/set05/v180"): "expected-refusal",
    ("non-regressions", "nonRegressions/set06/v243"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set05/v098"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set05/v099"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set05/v100"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set06/v263"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set06/v371"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set06/v372"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set07/v396"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set07/v403"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set04/lh140"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set06/v344"): "unsupported-fortad-pointer-ownership",
    ("non-regressions", "nonRegressions/set12/f03typf02"): "unsupported-fortad-abstract-polymorphic-context",
    ("non-regressions", "nonRegressions/set12/mvo35"): "unsupported-fortad-polymorphic-procedure-pointer",
    ("non-regressions", "nonRegressions/set04/v030"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set07/v534"): "unsupported-fortad-pointer-ownership",
    ("non-regressions", "nonRegressions/set07/v535"): "unsupported-fortad-pointer-ownership",
    ("non-regressions", "nonRegressions/set12/mvo34"): "unsupported-fortad-polymorphic-procedure-pointer",
    ("non-regressions", "nonRegressions/set05/v197"): "unsupported-fortad-array-section-rank",
    ("non-regressions", "nonRegressions/set06/v339"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set04/lh113"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set11/ompl07"): "unsupported-fortad-openmp-directive",
    ("non-regressions", "nonRegressions/set05/v179"): "unsupported-fortad-active-io",
    ("non-regressions", "nonRegressions/set06/v341"): "unsupported-fortad-allocatable-derived-component",
    ("non-regressions", "nonRegressions/set07/v434"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set07/v542"): "unsupported-fortad-allocatable-lifetime",
    ("non-regressions", "nonRegressions/set04/lh107"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set05/v152"): "expected-refusal",
    ("non-regressions", "nonRegressions/set03/cm04"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set05/v086"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set05/v200"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set07/v483"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set10/lh221"): "unsupported-fortad-array-section-rank",
    ("non-regressions", "nonRegressions/set07/v526"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set03/lh097"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set05/v178"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set04/lh162"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set06/v228"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set03/lh043"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set03/cm24"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/lh094"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set04/ptr09"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set06/v222"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set07/v436"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set03/bd17"): "unsupported-fortad-dependent-inference",
    ("non-regressions", "nonRegressions/set04/lh126"): "unsupported-fortad-procedure-pointer-callback",
    ("non-regressions", "nonRegressions/set05/v144"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set06/v254"): "unsupported-fortad-no-independent-variable",
    ("non-regressions", "nonRegressions/set11/mvo02"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set07/v460"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set04/v031"): "unsupported-fortad-procedure-call-actual",
    ("non-regressions", "nonRegressions/set05/v148"): "unsupported-fortad-dependent-inference",
    ("large-examples", "examples/big01/v235"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set04/lh127"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set04/lh134"): "unsupported-fortad-allocatable-lifetime",
    ("non-regressions", "nonRegressions/set04/lh146"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set11/v540a"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set11/v541a"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set11/lh011"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set11/vpf17"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set03/cm07"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/cm09"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set04/v006"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set11/v006"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set04/lh156"): "expected-refusal",
    ("non-regressions", "nonRegressions/set07/v521"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set12/mvo31"): "unsupported-fortad-polymorphic-type-bound-procedure",
    ("non-regressions", "nonRegressions/set12/mvo32"): "unsupported-fortad-procedure-pointer-callback",
    ("non-regressions", "nonRegressions/set03/cm30"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/cmv07"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set06/v237"): "expected-refusal",
    ("non-regressions", "nonRegressions/set10/lh234"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set06/v285"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set04/lh176"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/cmv02"): "probed-fortad-generated-no-runtime-claim",
    ("non-regressions", "nonRegressions/set03/cmv03"): "probed-fortad-generated-no-runtime-claim",
    ("non-regressions", "nonRegressions/set03/cm31"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/cm32"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set05/v194"): "probed-fortad-generated-no-runtime-claim",
    ("non-regressions", "nonRegressions/set06/v351"): "unsupported-fortad-generic-intrinsic",
    ("non-regressions", "nonRegressions/set05/v058"): "unsupported-fortad-generic-intrinsic",
    ("non-regressions", "nonRegressions/set05/v176"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set03/cmv04"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set05/v175"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set06/v364"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set04/lh112"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/lh051"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set03/cm25"): "unsupported-fortad-derived-component-allocation",
    ("non-regressions", "nonRegressions/set04/v004"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set07/v531"): "unsupported-fortad-generic-intrinsic",
    ("non-regressions", "nonRegressions/set04/lh108"): "unsupported-fortad-global-mutable-state",
    ("non-regressions", "nonRegressions/set04/v048"): "runnable-ported",
    ("non-regressions", "nonRegressions/set05/v077"): "unsupported-fortad-invalid-generated-interface",
    ("non-regressions", "nonRegressions/set11/vpf20"): "unsupported-fortad-derived-type-component",
    ("non-regressions", "nonRegressions/set10/lh230"): "unsupported-fortad-pointer-alias-lifetime",
    ("non-regressions", "nonRegressions/set10/lh232"): "unsupported-fortad-pointer-alias-lifetime",
}


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
        self.assertEqual(len(rows), 1101)
        self.assertEqual(
            Counter(row["queue_category"] for row in rows),
            Counter({
                "mixed-language-risk": 74,
                "parser-or-invalid-risk": 0,
                "no-entry-point-evidence": 0,
                "runnable-program-candidate": 238,
                "runnable-procedure-candidate": 789,
            }),
        )
        self.assertEqual(sum(row["dependency_risk"] for row in rows), 112)
        self.assertEqual(
            sum("missing-dependency-risk" in row["risk_categories"] for row in rows),
            112,
        )

    def test_measured_shard_closes_exactly_four_rows(self):
        root = Path(__file__).resolve().parent.parent
        ledger = queue.read_ledger(root / "docs/corpora/tapenade-status.csv")
        observed = {
            (row["component"], row["path"]): row["status"]
            for row in ledger
            if (row["component"], row["path"]) in MEASURED_SHARD_CLOSURES
        }
        self.assertEqual(observed, MEASURED_SHARD_CLOSURES)
        queued = {
            (row["component"], row["path"])
            for row in (
                json.loads(line)
                for line in (root / "docs/corpora/tapenade-fortran-queue.jsonl").read_text().splitlines()
            )
        }
        untriaged = {
            (row["component"], row["path"])
            for row in ledger
            if row["status"] == "untriaged"
        }
        self.assertEqual(queued, untriaged)
        self.assertTrue(set(MEASURED_SHARD_CLOSURES).isdisjoint(queued))
        self.assertEqual(len(queued), 1101)

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
