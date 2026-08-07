"""Contract and independent source/compiler checks for the v067 boundary."""

from __future__ import annotations

import csv
import importlib.util
import os
import subprocess
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CASE = ROOT / "cases/tapenade-set05"


def load_oracle():
    path = CASE / "v067_oracle.py"
    spec = importlib.util.spec_from_file_location("tapenade_set05_v067_oracle", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class V067BoundaryTests(unittest.TestCase):
    def test_result_records_strict_and_legacy_gates(self) -> None:
        report = (CASE / "v067_result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal",
            "upstream_exact_strict_compile: program.f90=1 program_d.f90=1 program_p.f90=1",
            "upstream_legacy_compile: program.f90=0 program_d.f90=0 program_p.f90=0",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=1 tangent=1 reverse=1",
            "tapenade_fresh_legacy_compile: parser=0 tangent=0 reverse=0",
            "fortad_parser: pass-exact-procedure-extraction status=0",
            "fortad_forward: expected-refusal",
            "fortad_reverse: expected-refusal",
            "oracle_status: pass",
            "upstream_sha256:",
            "fresh_tapenade_sha256:",
        ):
            self.assertIn(marker, report)

    def test_ledger_closes_only_v067(self) -> None:
        with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        self.assertEqual(rows["nonRegressions/set05/v067"]["status"], "expected-refusal")
        self.assertEqual(rows["nonRegressions/set05/v067"]["fortad_result"], "expected-refusal-forward-reverse-generic-call-no-output")
        self.assertEqual(rows["nonRegressions/set05/v068"]["status"], "untriaged")

    def test_manifest_pins_modern_boundary(self) -> None:
        with (CASE / "v067_manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["fortad_revision"], "db0f3afaf2cb709a5c7d2949cae74b3f3a581f51")
        self.assertEqual(manifest["classification"], "expected-refusal")
        self.assertIn("nonstandard REAL*8", " ".join(manifest["dependencies"]))

    def test_independent_source_oracle_passes(self) -> None:
        oracle = load_oracle()
        upstream = Path(os.environ.get("TAPENADE_REPO", str(ROOT / "upstream/tapenade")))
        if not upstream.is_dir():
            upstream = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
        source_dir = upstream / "nonRegressions/set05/v067"
        completed = subprocess.run(
            ["python3", str(CASE / "v067_oracle.py"), str(source_dir)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("oracle_status: pass", completed.stdout)
        self.assertTrue(hasattr(oracle, "run"))


if __name__ == "__main__":
    unittest.main()
