#!/usr/bin/env python3
"""Contract and independent-oracle checks for the next5 shard."""

from __future__ import annotations

import csv
import hashlib
import json
import subprocess
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CASE = Path(__file__).resolve().parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_contract() -> None:
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    result = json.loads((CASE / "result.json").read_text(encoding="utf-8"))
    with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="", encoding="utf-8") as stream:
        ledger = {(row["component"], row["path"]): row for row in csv.DictReader(stream)}
    assert result["shard_id"] == manifest["shard_id"]
    assert result["upstream_revision"] == manifest["upstream_revision"]
    assert result["fortad_revision"] == manifest["fortad_revision"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"]
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"]
    assert result["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4
    expected = {
        "set11-v540a": (159, "allocatable=6; pointer=1; interface=2; dimension=17", "unsupported-fortad-pointer-alias-lifetime"),
        "set06-v339": (88, "pointer=4; type(=4", "unsupported-fortad-pointer-alias-lifetime"),
        "set05-v197": (30, "allocatable=1; type(=2", "unsupported-fortad-array-section-rank"),
        "set11-v541a": (159, "allocatable=7; interface=2; dimension=17", "unsupported-fortad-pointer-alias-lifetime"),
    }
    assert {case["id"] for case in result["cases"]} == set(expected)
    for case in result["cases"]:
        score, features, classification = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"]) == (score, features, classification)
        assert case["selection"] == "modern-feature-score-then-queue-order-real-source-entry"
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert case["probe_status"] == "probed"
        assert set(case["modes"]) == {"parser", "forward", "reverse"}
        assert case["independent_oracle"]["status"] == "pass"
        assert all(value["status"] == "pass" for value in case["exact_source_checks"].values())
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification
        assert row["entry_point"] == case["entry_point"]
        assert row["modes"] == "parser|forward|reverse"
        assert "no-derivative-support-claim" in row["oracle"]
        assert row["tapenade_result"].startswith("pass-")
        assert "refused" in row["fortad_result"]
        for mode, engines in case["modes"].items():
            assert engines["tapenade"]["status"] == "pass"
            if case["id"] == "set12-mvo31" and mode == "parser":
                assert engines["fortad"]["status"] == "pass"
            else:
                assert engines["fortad"]["status"] == "refused"
    generated_expectations = {case["id"]: {"parser": "pass", "forward": "pass", "reverse": "pass"} for case in result["cases"]}
    for case in result["cases"]:
        observed = {
            mode: next(iter(engines["tapenade"]["generated_syntax"].values()))["status"]
            for mode, engines in case["modes"].items()
        }
        assert observed == generated_expectations[case["id"]]
    needles = {
        "set11-v540a": "unsupported aliasing declaration 'z'",
        "set06-v339": "unsupported aliasing declaration 'next_elem'",
        "set05-v197": "unsupported array section",
        "set11-v541a": "unsupported aliasing declaration 'z'",
    }
    for case in result["cases"]:
        assert needles[case["id"]] in case["modes"]["parser"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v197-block", "v339-linked-pointer", "v540a-allocations", "v541a-allocations"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
