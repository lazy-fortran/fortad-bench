"""Contract checks for the set03 tranche Q evidence."""

import csv
import hashlib
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "cases/tapenade-set03/tranche-q-manifest.toml"
RESULT = ROOT / "results/tapenade_set03_tranche_q_validation.txt"
LEDGER = ROOT / "docs/corpora/tapenade-status.csv"


class Set03TrancheQTests(unittest.TestCase):
    def test_measured_report_has_independent_or_refusal_gates(self):
        report = RESULT.read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "ht05_refusal_oracle: exact nonzero JVP/VJP status",
            "ht06_refusal_oracle: exact nonzero JVP/VJP status",
            "ht12_refusal_oracle: generated JVP/VJP compile failures",
            "independent_oracle: hand analytic JVP/VJP",
        ):
            self.assertIn(marker, report)

    def test_manifest_pins_both_engines_and_four_rows(self):
        manifest = tomllib.loads(MANIFEST.read_text())
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "a1c9f25f87eaadf700ba47ee3e841a0fb41585a3",
        )
        self.assertEqual(
            [row["id"] for row in manifest["case"]],
            ["ht05", "ht06", "ht12", "ht13"],
        )

    def test_ledger_rows_match_measured_classifications(self):
        with LEDGER.open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        expected = {
            "nonRegressions/set03/ht05": (
                "expected-refusal",
                "expected-refusal-allocation-line-6-no-output",
            ),
            "nonRegressions/set03/ht06": (
                "expected-refusal",
                "expected-refusal-array-section-line-5-no-output",
            ),
            "nonRegressions/set03/ht12": (
                "expected-refusal",
                "expected-refusal-generated-compile-hidden-extent-and-duplicate-adjoint",
            ),
            "nonRegressions/set03/ht13": (
                "runnable-ported",
                "pass-transform-compile-runtime",
            ),
        }
        for path, (status, result) in expected.items():
            self.assertEqual(rows[path]["status"], status)
            self.assertEqual(rows[path]["fortad_result"], result)

    def test_case_sources_are_byte_exact_upstream(self):
        for case in ("ht05", "ht06", "ht12", "ht13"):
            local = ROOT / f"cases/tapenade-set03/{case}.f90"
            upstream = ROOT / f"upstream/tapenade/nonRegressions/set03/{case}/program.f90"
            self.assertEqual(
                hashlib.sha256(local.read_bytes()).digest(),
                hashlib.sha256(upstream.read_bytes()).digest(),
                case,
            )


if __name__ == "__main__":
    unittest.main()
