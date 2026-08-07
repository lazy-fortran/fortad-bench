"""Contract checks for the lh009 invalid-source refusal evidence."""

from pathlib import Path
import tomllib
import unittest

ROOT = Path(__file__).resolve().parent.parent
CASE = ROOT / "cases" / "tapenade-set01"
RESULT = ROOT / "results" / "tapenade_set01_lh009_refusal_validation.txt"


class Lh009RefusalEvidenceTests(unittest.TestCase):
    def test_report_records_refusal_and_independent_oracle(self):
        report = RESULT.read_text()
        for marker in (
            "upstream_exact_source_compile_statuses:",
            "tapenade_generation_status: parser=pass tangent=pass reverse=pass",
            "tapenade_generated_strict_compile_statuses:",
            "fortad_result: not-run-invalid-upstream-source",
            "port_result: independent-oracle-only-not-counted-as-support",
            "refusal_oracle_status: pass",
        ):
            self.assertIn(marker, report)

    def test_manifest_preserves_invalid_classification(self):
        with (CASE / "lh009-manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["classification"],
                         "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["case"][0]["ported_entry_point"],
                         "set01_lh009(a_in,b_in,s,a_out,b_out)")

    def test_oracle_port_has_the_loop_and_hand_reverse(self):
        source = (CASE / "lh009.f90").read_text()
        hand = (CASE / "hand_derivative_lh009.f90").read_text()
        self.assertIn("do i = s, 1000 - s", source)
        self.assertIn("subroutine lh009_hand_jvp", hand)
        self.assertIn("subroutine lh009_hand_vjp", hand)


if __name__ == "__main__":
    unittest.main()
