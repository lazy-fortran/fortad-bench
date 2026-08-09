#!/usr/bin/env python3
"""Independent contract tests for the size-sweep protocol."""

from __future__ import annotations

import csv
import io
import json
import tempfile
import unittest
from pathlib import Path

import enzyme_suite_sweep as sweep


class EnzymeSuiteSweepContractTest(unittest.TestCase):
    def test_size_parser_preserves_requested_sizes_and_rejects_bad_input(self):
        self.assertEqual(sweep.parse_sizes("100, 1000,10000"), [100, 1000, 10000])
        with self.assertRaises(ValueError):
            sweep.parse_sizes("100,100")
        with self.assertRaises(ValueError):
            sweep.parse_sizes("100,0")

    def test_statistics_are_median_min_max_not_best_only(self):
        summary = sweep.summarize([0.004, 0.001, 0.003, 0.010, 0.002])
        self.assertEqual(summary["trials"], 5)
        self.assertEqual(summary["median"], 0.003)
        self.assertEqual(summary["min"], 0.001)
        self.assertEqual(summary["max"], 0.010)

    def test_recorded_fixture_contract_validates_each_size_and_statistic(self):
        # These are deterministic contract samples, not performance results.
        text = """workload,engine,problem_size,input_count,n,repetitions,trials,seconds_median,seconds_min,seconds_max,ns_per_input_median,ns_per_input_min,ns_per_input_max,timing_clock,run_id,provenance_file
euler,fortad,100,100,100,3,5,3e-3,1e-3,1e-2,10000,3333,33333,system_clock_wall,fixture,fixture.json
euler,enzyme,100,100,100,3,5,4e-3,2e-3,1.2e-2,13333,6666,40000,system_clock_wall,fixture,fixture.json
euler,fortad,1000,1000,1000,3,5,3e-2,1e-2,1e-1,10000,3333,33333,system_clock_wall,fixture,fixture.json
"""
        rows = list(csv.DictReader(io.StringIO(text)))
        sweep.validate_result_rows(rows, [100, 1000])
        self.assertEqual(sweep.result_rate_field(rows[0]), "ns_per_input_median")
        self.assertEqual(sweep.result_time_field(rows[0]), "seconds_median")

    def test_provenance_is_json_and_records_dry_run_without_measurements(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            (root / ".git").mkdir()
            path = root / "provenance.json"
            metadata = sweep.make_metadata(
                root,
                run_id="fixture",
                status="dry-run",
                sizes=[100, 1000],
                trials=5,
                repetitions="auto",
                output="results/enzyme_suite_sweep.csv",
                provenance_file=str(path),
                missing_tools=["Enzyme plugin"],
            )
            sweep.write_metadata(path, metadata)
            loaded = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(loaded["status"], "dry-run")
            self.assertEqual(loaded["problem_sizes"], [100, 1000])
            self.assertEqual(loaded["timing_clock"], "system_clock_wall")
            self.assertIn("Enzyme plugin", loaded["missing_tools"])
            self.assertIsNone(loaded["peak_rss_kb"])


if __name__ == "__main__":
    unittest.main()
