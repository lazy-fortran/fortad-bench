"""Contract checks for the set05 v052 evidence tranche."""

import hashlib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class V052EvidenceTests(unittest.TestCase):
    def test_report_records_independent_gates(self):
        report = (ROOT / "results/tapenade_set05_v052_validation.txt").read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "upstream_exact_source_compile_statuses:",
            "fortad_transform_compile_statuses:",
            "independent_oracle: hand JVP/VJP",
        ):
            self.assertIn(marker, report)

    def test_manifest_and_runner_are_pinned(self):
        manifest = (
            ROOT / "cases/tapenade-set05/tranche-v052-manifest.toml"
        ).read_text()
        self.assertIn(
            'upstream_revision = "e59864cab441d4175df75383b3ff58c3dcd26df9"',
            manifest,
        )
        self.assertIn('id = "v052"', manifest)
        self.assertIn('independent = ["x"]', manifest)

    def test_report_hashes_owned_sources(self):
        report = (ROOT / "results/tapenade_set05_v052_validation.txt").read_text()
        hashes = {}
        for line in report.split("source_sha256:\n", 1)[1].split(
            "run_output:", 1
        )[0].splitlines():
            if line.strip():
                digest, relative = line.split()
                hashes[relative] = digest
        for relative in (
            "cases/tapenade-set05/v052.f90",
            "cases/tapenade-set05/hand_derivative_v052.f90",
            "cases/tapenade-set05/tranche-v052-manifest.toml",
            "cases/tapenade-set05/tranche-v052.md",
            "harness/bench_tapenade_set05_v052.f90",
            "scripts/bench_tapenade_set05_v052.sh",
        ):
            digest = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
            self.assertEqual(hashes[relative], digest)


if __name__ == "__main__":
    unittest.main()
