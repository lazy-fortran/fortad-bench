#!/usr/bin/env python3
"""Focused contract and independent-mathematics checks for tranche B."""

from __future__ import annotations

import csv
import math
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESULT = ROOT / "results/tapenade_set05_set06_tranche_b_validation.txt"
LEDGER = ROOT / "docs/corpora/tapenade-status.csv"


class Set05Set06TrancheBEvidenceTests(unittest.TestCase):
    def test_manifests_pin_the_four_disjoint_cases(self) -> None:
        expected = {
            ROOT / "cases/tapenade-set05/tranche-b-v150-v168-manifest.toml": {"v150", "v168"},
            ROOT / "cases/tapenade-set06/tranche-b-v314-v379-manifest.toml": {"v314", "v379"},
        }
        for path, ids in expected.items():
            with path.open("rb") as stream:
                manifest = tomllib.load(stream)
            self.assertEqual(
                manifest["upstream_revision"],
                "e59864cab441d4175df75383b3ff58c3dcd26df9",
            )
            self.assertEqual(
                manifest["fortad_revision"],
                "db0050259520b618e2a0aeba203c85a7613943b5",
            )
            self.assertEqual({case["id"] for case in manifest["case"]}, ids)
            self.assertTrue(all(case["classification"] == "runnable-ported" for case in manifest["case"]))

    def test_ledger_closes_only_the_four_selected_rows(self) -> None:
        with LEDGER.open(newline="") as stream:
            rows = {row["path"]: row for row in csv.DictReader(stream)}
        for path in (
            "nonRegressions/set05/v150",
            "nonRegressions/set05/v168",
            "nonRegressions/set06/v314",
            "nonRegressions/set06/v379",
        ):
            self.assertEqual(rows[path]["status"], "runnable-ported")
            self.assertEqual(rows[path]["fortad_result"], "pass-transform-compile-runtime")
            self.assertIn("pass-fresh-parser", rows[path]["tapenade_result"])

    def test_result_records_all_generated_and_oracle_gates(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "tapenade_commit: e59864cab441d4175df75383b3ff58c3dcd26df9",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "upstream_exact_source_compile_statuses:",
            "fortad_transform_compile_statuses:",
            "independent_oracle: hand JVP/VJP",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)
        for case in ("v150", "v168", "v314", "v379"):
            self.assertIn(f"tapenade/{case}/parser/", report)
            self.assertIn(f"tapenade/{case}/forward/", report)
            self.assertIn(f"tapenade/{case}/reverse/", report)

    def test_independent_math_contract(self) -> None:
        t, td, fb = 0.7, -0.3, 0.8
        f = math.exp(t * t)
        self.assertAlmostEqual(f, math.exp(0.49), places=14)
        self.assertAlmostEqual(2.0 * t * f * td, -0.42 * f, places=14)
        self.assertAlmostEqual(2.0 * t * f * fb, 1.12 * f, places=14)

        x = (1.0, 3.0, -2.5, 0.5)
        xd = (0.3, -0.2, 0.4, -0.5)
        yb = (0.7, -0.3, 0.5, -0.2)
        jvp = []
        vjp = []
        for value, direction, seed in zip(x, xd, yb):
            u = abs(2.0 * value)
            du = math.copysign(2.0, value) * direction
            v = abs(u - 4.0)
            dv = math.copysign(1.0, u - 4.0) * du
            jvp.append((dv * u + v * du))
            vjp.append(seed * (v + u * math.copysign(1.0, u - 4.0)) * math.copysign(2.0, value))
        self.assertAlmostEqual(sum(a * b for a, b in zip(yb, jvp)), sum(a * b for a, b in zip(vjp, xd)), places=13)

        y, z, yd, zd = 1.2, 2.3, -0.4, 0.7
        self.assertAlmostEqual(yd + 2.0 * z * zd, -0.4 + 3.22, places=14)
        self.assertAlmostEqual(0.8 * yd + (1.6 * z) * zd, 0.8 * (-0.4 + 3.22), places=14)
        self.assertAlmostEqual(sum((1.0, 2.0, 3.0, 4.0)), 10.0, places=14)
        self.assertAlmostEqual(sum((0.3, -0.2, 0.4, -0.5)), 0.0, places=14)


if __name__ == "__main__":
    unittest.main()
