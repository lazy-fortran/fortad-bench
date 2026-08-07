"""Committed evidence checks for the Tapenade set01 bd01--bd03 tranche."""

import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESULT = ROOT / "results" / "tapenade_set01_tranche_l_bd_ht_validation.txt"
MANIFEST = ROOT / "cases" / "tapenade-set01" / "tranche-l-bd-ht-manifest.toml"
LEDGER = ROOT / "docs" / "corpora" / "tapenade-status.csv"


class TrancheLBdHtEvidence(unittest.TestCase):
    def test_result_has_fresh_generation_and_independent_oracle(self):
        result = RESULT.read_text(encoding="utf-8")
        self.assertIn("tapenade_commit: e59864cab441d4175df75383b3ff58c3dcd26df9", result)
        self.assertIn("tapenade_oracle: fresh parser, tangent, and adjoint outputs", result)
        self.assertIn("oracle: independent hand JVP/VJP, four-step central differences", result)
        self.assertIn("oracle_status: pass", result)
        for case_id in ("bd01", "bd02", "bd03"):
            self.assertIn(f"{case_id}_tapenade_forward_source_bytes:", result)
            self.assertIn(f"{case_id}_tapenade_reverse_source_bytes:", result)
            self.assertIn(f"{case_id}_fortad_forward_source_bytes:", result)
            self.assertIn(f"{case_id}_fortad_reverse_source_bytes:", result)

    def test_manifest_and_ledger_close_the_same_cases(self):
        manifest = MANIFEST.read_text(encoding="utf-8")
        for case_id in ("bd01", "bd02", "bd03"):
            self.assertIn(f'id = "{case_id}"', manifest)
            self.assertIn(
                f'upstream_source = "nonRegressions/set01/{case_id}/program.f"',
                manifest,
            )
        with LEDGER.open(encoding="utf-8", newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        for case_id in ("bd01", "bd02", "bd03"):
            row = rows[f"nonRegressions/set01/{case_id}"]
            self.assertEqual(row["status"], "runnable-ported")
            self.assertEqual(row["tapenade_result"], "pass-fresh-parser-tangent-reverse-generation-generated-compile")
            self.assertEqual(row["fortad_result"], "pass-transform-compile-runtime")


if __name__ == "__main__":
    unittest.main()
