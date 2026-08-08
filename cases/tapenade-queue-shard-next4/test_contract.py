#!/usr/bin/env python3
"""Contract and independent-oracle checks for the next4 shard."""

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
    for key in ("upstream_revision", "fortad_revision", "selection_queue_sha256", "selection_batch_sha256", "current_queue_sha256", "current_batch_sha256"):
        assert result[key] == manifest[key]
    assert result["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4
    expected = {
        "set06-v342": (84, "pointer=6", "unsupported-fortad-pointer-alias-lifetime"),
        "set12-mvo33": (74, "abstract=1; pointer=2; procedure=2; interface=2", "unsupported-fortad-procedure-pointer-callback"),
        "set11-vpf09": (67, "pointer=1; contiguous=5; dimension=1", "unsupported-fortad-pointer-alias-lifetime"),
        "set06-v335": (32, "allocatable=1; pointer=1; optional=1", "unsupported-fortad-no-independent-variable"),
    }
    assert {case["id"] for case in result["cases"]} == set(expected)
    for case in result["cases"]:
        score, features, classification = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"]) == (score, features, classification)
        assert case["selection"] == "modern-feature-score-then-queue-order-real-source-entry"
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == [] and case["compiler_extra_source_files"] == []
        assert case["probe_status"] == "probed" and case["dependency_risk"] is False and case["dependency_hints"] == []
        assert set(case["modes"]) == {"parser", "forward", "reverse"}
        assert case["independent_oracle"]["status"] == "pass"
        assert all(value["status"] == "pass" for value in case["exact_source_checks"].values()) if "exact_source_checks" in case else True
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification and row["entry_point"] == case["entry_point"]
        assert row["modes"] == "parser|forward|reverse" and "no-derivative-support-claim" in row["oracle"]
        for mode, engines in case["modes"].items():
            assert engines["tapenade"]["status"] == "pass"
        if case["id"] == "set06-v335":
            assert case["modes"]["parser"]["fortad"]["status"] == "pass"
            assert case["modes"]["forward"]["fortad"]["status"] == "refused" and case["modes"]["reverse"]["fortad"]["status"] == "refused"
        else:
            assert all(engines["fortad"]["status"] == "refused" for engines in case["modes"].values())


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v342-pointer", "mvo33-dispatch", "vpf09-layout", "v335-declarations"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
