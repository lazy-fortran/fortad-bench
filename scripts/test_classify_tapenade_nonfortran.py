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
            "nonRegressions/set01/B05",
            "nonRegressions/set01/bd07",
            "nonRegressions/set01/ht01",
            "nonRegressions/set01/lh043",
            "nonRegressions/set03/cm05",
            "nonRegressions/set03/cm10",
            "nonRegressions/set03/cm34",
            "nonRegressions/set03/lh013",
            "nonRegressions/set05/v077",
            "nonRegressions/set11/vpf20",
            "nonRegressions/set10/lh230",
            "nonRegressions/set10/lh232",
            "nonRegressions/set03/cmv04",
            "nonRegressions/set03/cm31",
            "nonRegressions/set03/cm32",
            "nonRegressions/set05/v058",
            "nonRegressions/set05/v194",
            "nonRegressions/set05/v175",
            "nonRegressions/set05/v176",
            "nonRegressions/set06/v364",
            "nonRegressions/set04/lh112",
            "nonRegressions/set03/lh051",
            "nonRegressions/set03/cm25",
            "nonRegressions/set04/v004",
            "nonRegressions/set07/v531",
            "nonRegressions/set04/lh108",
            "nonRegressions/set04/v048",
            "nonRegressions/set06/v351",
            "nonRegressions/set06/v335",
            "nonRegressions/set06/v342",
            "nonRegressions/set04/lh109",
            "nonRegressions/set04/lh121",
            "nonRegressions/set04/lh111",
            "nonRegressions/set07/v479",
            "nonRegressions/set07/v520",
            "nonRegressions/set11/vpf19",
            "examples/big01/B04",
            "nonRegressions/set05/v069",
            "nonRegressions/set05/v193",
            "nonRegressions/set05/v196",
            "nonRegressions/set05/v202",
            "nonRegressions/set06/v220",
            "nonRegressions/set06/v232",
            "nonRegressions/set04/lh140",
            "nonRegressions/set06/v344",
            "nonRegressions/set04/v030",
            "nonRegressions/set07/v534",
            "nonRegressions/set07/v535",
            "nonRegressions/set12/f03typf02",
            "nonRegressions/set12/mvo35",
            "nonRegressions/set12/mvo34",
            "nonRegressions/set12/mvo31",
            "nonRegressions/set12/mvo32",
            "nonRegressions/set11/vpf09",
            "nonRegressions/set12/mvo33",
            "nonRegressions/set11/v540a",
            "nonRegressions/set11/v541a",
            "nonRegressions/set11/lh011",
            "nonRegressions/set11/vpf17",
            "nonRegressions/set06/v339",
            "nonRegressions/set05/v197",
            "nonRegressions/set04/lh156",
            "nonRegressions/set07/v521",
            "nonRegressions/set03/cm30",
            "nonRegressions/set03/cmv07",
            "nonRegressions/set06/v237",
            "nonRegressions/set10/lh234",
            "nonRegressions/set06/v290",
            "nonRegressions/set03/cm33",
            "nonRegressions/set03/lh056",
            "nonRegressions/set03/cm26",
            "todoF90/REFERENCES/bd01",
            "todoF90/REFERENCES/bd11",
            "todoF90/REFERENCES/v01",
            "todoF90/REFERENCES/v02",
            "todoF90/REFERENCES/v05",
            "todoF90/REFERENCES/v07",
            "todoF90/REFERENCES/v100",
            "todoF90/REFERENCES/v101",
            "todoF90/REFERENCES/v385",
            "todoF90/REFERENCES/v402",
            "todoF90/REFERENCES/v412",
            "todoF90/REFERENCES/v413",
            "todoF90/REFERENCES/v414",
            "todoF90/REFERENCES/v415",
            "todoF90/REFERENCES/v416",
            "todoF90/REFERENCES/v417",
            "todoF90/REFERENCES/v418",
            "todoF90/REFERENCES/v419",
            "todoF90/REFERENCES/v421",
            "todoF90/REFERENCES/v422",
            "todoF90/REFERENCES/v425",
            "todoF90/REFERENCES/v426",
            "todoF90/REFERENCES/v427",
            "todoF90/REFERENCES/v469",
            "todoF90/REFERENCES/v500",
            "todoF90/REFERENCES/v503",
            "todoF90/REFERENCES/v504",
            "todoF90/REFERENCES/v505",
            "todoF90/REFERENCES/v508",
            "todoF90/REFERENCES/v519",
            "todoF90/REFERENCES/v526",
            "todoF90/REFERENCES/v547",
            "todoF90/REFERENCES/v144",
            "todoF90/REFERENCES/v270",
            "todoF90/REFERENCES/v322",
            "todoF90/REFERENCES/v377",
            "nonRegressions/set01/bd01",
            "nonRegressions/set01/bd02",
            "nonRegressions/set01/bd03",
            "nonRegressions/set01/bd06",
            "nonRegressions/set01/bd01",
            "nonRegressions/set01/bd02",
            "nonRegressions/set01/bd03",
            "nonRegressions/set01/lh001",
            "nonRegressions/set01/lh002",
            "nonRegressions/set01/lh012",
            "nonRegressions/set01/lh013",
            "nonRegressions/set01/lh014",
            "nonRegressions/set01/lh003",
            "nonRegressions/set01/lh019",
            "nonRegressions/set01/lh004",
            "nonRegressions/set01/lh005",
            "nonRegressions/set01/lh006",
            "nonRegressions/set01/lh008",
            "nonRegressions/set01/lh010",
            "nonRegressions/set01/lh023",
            "nonRegressions/set01/lh032",
            "nonRegressions/set01/lh049",
            "nonRegressions/set01/lh057",
            "nonRegressions/set01/lh058",
            "nonRegressions/set01/lh068",
            "nonRegressions/set01/lh066",
            "nonRegressions/set01/lh088",
            "nonRegressions/set01/lh134",
            "nonRegressions/set01/lh078",
            "nonRegressions/set01/lh079",
            "nonRegressions/set01/lh136",
            "nonRegressions/set01/lh144",
            "nonRegressions/set01/lh081",
            "nonRegressions/set01/lh083",
            "nonRegressions/set01/lh084",
            "nonRegressions/set01/lh087",
            "nonRegressions/set01/lh089",
            "nonRegressions/set01/lh090",
            "nonRegressions/set01/lh093",
            "nonRegressions/set01/lh094",
            "nonRegressions/set01/lh097",
            "nonRegressions/set01/lh098",
            "nonRegressions/set01/lh102",
            "nonRegressions/set01/lh103",
            "nonRegressions/set01/B01",
            "nonRegressions/set01/lh091",
            "nonRegressions/set01/lh095",
            "nonRegressions/set01/lh096",
            "nonRegressions/set01/B03",
            "nonRegressions/set01/ala03",
            "nonRegressions/set01/ala00",
            "nonRegressions/set01/ala01",
            "nonRegressions/set01/ala02",
            "nonRegressions/set01/ala04",
            "nonRegressions/set01/ala05",
            "nonRegressions/set01/bd04",
            "nonRegressions/set01/ht02",
            "nonRegressions/set01/ht03",
            "nonRegressions/set01/lh104",
            "nonRegressions/set01/lh105",
            "nonRegressions/set01/lh107",
            "nonRegressions/set01/lh109",
            "todoF90/REFERENCES/v420",
            "nonRegressions/set12/f03typf01",
            "ADFirstAidKit/testMemSizef.f",
            "ADFirstAidKit/validityTest.f",
            "nonRegressions/set01/lh016",
            "nonRegressions/set01/lh017",
            "nonRegressions/set01/lh022",
            "nonRegressions/set01/lh028",
            "nonRegressions/set01/lh033",
            "nonRegressions/set01/lh039",
            "nonRegressions/set01/lh040",
            "nonRegressions/set01/lh052",
            "nonRegressions/set01/lh054",
            "nonRegressions/set01/lh055",
            "nonRegressions/set01/lh056",
            "nonRegressions/set01/lh074",
            "nonRegressions/set01/lh080",
            "nonRegressions/set01/lh082",
            "nonRegressions/set01/lh085",
            "nonRegressions/set01/lh092",
            "nonRegressions/set01/lh086",
            "nonRegressions/set01/lh018",
            "nonRegressions/set01/lh007",
            "nonRegressions/set01/lh009",
            "nonRegressions/set01/lh011",
            "nonRegressions/set01/lh015",
            "nonRegressions/set01/bd05",
            "nonRegressions/set01/lh020",
            "nonRegressions/set01/lh021",
            "nonRegressions/set01/lh024",
            "nonRegressions/set01/lh025",
            "nonRegressions/set01/lh026",
            "nonRegressions/set01/lh027",
            "nonRegressions/set01/lh029",
            "nonRegressions/set01/lh030",
            "nonRegressions/set01/lh031",
            "nonRegressions/set01/lh034",
            "nonRegressions/set01/lh035",
            "nonRegressions/set01/lh036",
            "nonRegressions/set01/lh037",
            "nonRegressions/set01/lh038",
            "nonRegressions/set01/lh041",
            "nonRegressions/set01/lh042",
            "nonRegressions/set01/lh044",
            "nonRegressions/set01/lh045",
            "nonRegressions/set01/lh046",
            "nonRegressions/set01/lh047",
            "nonRegressions/set01/lh048",
            "nonRegressions/set01/lh050",
            "nonRegressions/set01/lh051",
            "nonRegressions/set01/lh053",
            "nonRegressions/set01/lh059",
            "nonRegressions/set01/lh060",
            "nonRegressions/set01/lh061",
            "nonRegressions/set01/lh063",
            "nonRegressions/set01/lh064",
            "nonRegressions/set01/lh065",
            "nonRegressions/set01/lh067",
            "nonRegressions/set01/lh069",
            "nonRegressions/set01/lh070",
            "nonRegressions/set01/lh071",
            "nonRegressions/set01/lh072",
            "nonRegressions/set01/lh073",
            "nonRegressions/set01/lh075",
            "nonRegressions/set01/lh076",
            "nonRegressions/set01/lh077",
            "nonRegressions/set02/lh150",
            "nonRegressions/set02/lh193",
            "nonRegressions/set02/lh194",
            "nonRegressions/set02/lh163",
            "nonRegressions/set02/v103",
            "nonRegressions/set02/v128",
            "nonRegressions/set02/v130",
            "nonRegressions/set02/lh192",
            "nonRegressions/set02/lh196",
            "nonRegressions/set02/lh198",
            "nonRegressions/set02/v067",
            "nonRegressions/set03/ht09",
            "nonRegressions/set03/ht05",
            "nonRegressions/set03/ht06",
            "nonRegressions/set03/ht12",
            "nonRegressions/set03/ht13",
            "nonRegressions/set03/cm07",
            "nonRegressions/set03/cm09",
            "nonRegressions/set03/cmv02",
            "nonRegressions/set03/cmv03",
            "nonRegressions/set04/v006",
            "nonRegressions/set04/lh176",
            "nonRegressions/set11/v006",
            "nonRegressions/set04/lh110",
            "nonRegressions/set04/lh148",
            "nonRegressions/set04/lh128",
            "nonRegressions/set04/lh151",
            "nonRegressions/set04/lh152",
            "nonRegressions/set05/v052",
            "nonRegressions/set05/v054",
            "nonRegressions/set05/v060",
            "nonRegressions/set05/v061",
            "nonRegressions/set05/v062",
            "nonRegressions/set05/v064",
            "nonRegressions/set05/v065",
            "nonRegressions/set05/v066",
            "nonRegressions/set05/v067",
            "nonRegressions/set05/v068",
            "nonRegressions/set05/v125",
            "nonRegressions/set05/v137",
            "nonRegressions/set05/v150",
            "nonRegressions/set05/v168",
            "nonRegressions/set06/v234",
            "nonRegressions/set06/v314",
            "nonRegressions/set06/v379",
            "nonRegressions/set06/v285",
            "nonRegressions/set12/cmplxstep01",
            "nonRegressions/set12/f03fptr01",
            "nonRegressions/set12/jlb012",
            "nonRegressions/set12/profile01",
            "nonRegressions/set01/lh000",
            "nonRegressions/set02/v065",
            "nonRegressions/set04/v017",
            "nonRegressions/set04/v025",
            "nonRegressions/set05/v075",
            "nonRegressions/set05/v146",
            "nonRegressions/set05/v147",
            "nonRegressions/set05/v171",
            "nonRegressions/set05/v177",
            "nonRegressions/set05/v201",
            "nonRegressions/set05/v216",
            "nonRegressions/set06/v316",
            "nonRegressions/set06/v317",
            "nonRegressions/set06/v320",
            "nonRegressions/set06/v360",
            "nonRegressions/set06/v362",
            "nonRegressions/set04/lh159",
            "nonRegressions/set04/ptr07",
            "nonRegressions/set04/ptr08",
            "nonRegressions/set05/v180",
            "nonRegressions/set06/v243",
            "nonRegressions/set07/v485",
            "nonRegressions/set07/v523",
            "nonRegressions/set07/v544",
            "nonRegressions/set11/vmp06",
            "nonRegressions/set11/vmp07",
            "nonRegressions/set11/vpf16",
        })
        self.assertEqual(
            sum(row["status"] == "untriaged" for row in ledger),
            1197,
        )


if __name__ == "__main__":
    unittest.main()
