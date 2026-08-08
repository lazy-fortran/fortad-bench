#!/usr/bin/env python3
"""Contract and independent-oracle checks for the next3 shard."""

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
        "set04-lh109": (60, "pointer=2; type(=1; procedure=1; interface=2; dimension=2", "unsupported-fortad-derived-component-allocation"),
        "set12-mvo32": (54, "pointer=2; procedure=2; interface=2", "unsupported-fortad-procedure-pointer-callback"),
        "set12-mvo31": (48, "class(=1; type(=2; procedure=2", "unsupported-fortad-polymorphic-type-bound-procedure"),
        "set04-lh121": (37, "allocatable=1; pointer=1; dimension=3", "unsupported-fortad-pointer-alias-lifetime"),
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
    generated_expectations = {
        "set04-lh109": {"parser": "pass", "forward": "pass", "reverse": "refused"},
        "set12-mvo32": {"parser": "pass", "forward": "pass", "reverse": "pass"},
        "set12-mvo31": {"parser": "pass", "forward": "pass", "reverse": "pass"},
        "set04-lh121": {"parser": "pass", "forward": "pass", "reverse": "refused"},
    }
    for case in result["cases"]:
        observed = {
            mode: next(iter(engines["tapenade"]["generated_syntax"].values()))["status"]
            for mode, engines in case["modes"].items()
        }
        assert observed == generated_expectations[case["id"]]
    mvo31 = next(case for case in result["cases"] if case["id"] == "set12-mvo31")
    parser_product = next(iter(mvo31["modes"]["parser"]["fortad"]["generated_syntax"].values()))
    assert parser_product["status"] == "refused"
    assert "Derived type" in parser_product["stderr"]
    assert "being used before it is defined" in parser_product["stderr"]
    needles = {
        "set04-lh109": "elemental-expansion generic call 'baralloc'",
        "set12-mvo32": "unsupported procedure-pointer callback call 'pp'",
        "set12-mvo31": "active polymorphic receiver 'self'",
        "set04-lh121": "unsupported aliasing declaration 'mm1'",
    }
    for case in result["cases"]:
        if case["id"] == "set12-mvo31":
            text = case["modes"]["forward"]["fortad"]["stderr"]
        else:
            text = case["modes"]["parser"]["fortad"]["stderr"]
        assert needles[case["id"]] in text


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"lh109-local-component", "mvo32-callback", "mvo31-type-bound", "lh121-alias-lifetime"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
