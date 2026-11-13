"""Statistical contract checks for downstream measurement summaries."""

import csv
import json
from pathlib import Path
import tempfile
import unittest

from plot_downstream import summarize


class DownstreamSummaryTest(unittest.TestCase):
    def fixture(self, root, *, mode="measurement", omit=None):
        (root / "metadata.json").write_text(json.dumps(dict(
            mode=mode, status="complete", protocol=dict(samples=7, batch=20000, min_seconds=.05),
            inventory=[dict(suite="fortnum", operator="det2", arity=4)],
            source_sha256={"fortnum/det2": "source identity"})))
        with (root / "trials.csv").open("w", newline="") as stream:
            writer = csv.DictWriter(stream, ("suite", "operator", "engine", "sample", "ns_per_input",
                                            "seconds", "repetitions", "batch", "arity"))
            writer.writeheader()
            for sample in range(7):
                for engine, time in (("fortad-vjp", sample+1), ("enzyme", 2*(sample+1))):
                    if (engine, sample) != omit:
                        writer.writerow(dict(suite="fortnum", operator="det2", engine=engine,
                                             sample=sample, ns_per_input=time, seconds=time*.08,
                                             repetitions=1000, batch=20000, arity=4))

    def test_summary_uses_paired_samples_and_keeps_unavailable_contract(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            enzyme, tapenade = summarize(root)
            self.assertEqual((enzyme["ratio"], enzyme["ratio_min"], enzyme["ratio_max"]), (.5, .5, .5))
            self.assertEqual((enzyme["fortad_ns"], enzyme["reference_ns"]), (4, 8))
            self.assertEqual(tapenade["status"], "incomplete")

    def test_missing_sample_cannot_produce_a_ratio(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root, omit=("enzyme", 6))
            self.assertEqual(summarize(root)[0]["ratio"], "")

    def test_smoke_and_duplicate_records_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root, mode="smoke")
            with self.assertRaises(ValueError):
                summarize(root)
            self.fixture(root)
            with (root / "trials.csv").open("a") as stream:
                stream.write("fortnum,det2,enzyme,0,2,.16,1000,20000,4\n")
            with self.assertRaises(ValueError):
                summarize(root)

    def test_bad_normalization_or_short_trial_cannot_produce_a_ratio(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for field, value in (("seconds", ".001"), ("ns_per_input", "999")):
                self.fixture(root)
                path = root / "trials.csv"
                with path.open(newline="") as stream:
                    rows = list(csv.DictReader(stream))
                rows[0][field] = value
                with path.open("w", newline="") as stream:
                    writer = csv.DictWriter(stream, rows[0].keys())
                    writer.writeheader()
                    writer.writerows(rows)
                with self.assertRaises(ValueError):
                    summarize(root)

    def test_invalid_inventory_and_nonfinite_protocol_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for field in ("minimum", "arity"):
                self.fixture(root)
                path = root / "metadata.json"
                data = json.loads(path.read_text())
                if field == "minimum":
                    data["protocol"]["min_seconds"] = float("nan")
                else:
                    data["inventory"][0]["arity"] = 0
                path.write_text(json.dumps(data))
                with self.assertRaises(ValueError):
                    summarize(root)


if __name__ == "__main__":
    unittest.main()
