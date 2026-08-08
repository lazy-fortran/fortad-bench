"""Contract and independent-oracle checks for next16."""

from __future__ import annotations

import csv
import hashlib
import json
import re
import subprocess
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CASE = Path(__file__).resolve().parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_contract() -> None:
    manifest = tomllib.loads((CASE / "manifest.toml").read_text())
    result = json.loads((CASE / "result.json").read_text())
    with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
        ledger = {(row["component"], row["path"]): row for row in csv.DictReader(stream)}

    assert result["shard_id"] == manifest["shard_id"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4

    expected = {
        "set03-cm05": (42, "pointer=3", "unsupported-fortad-pointer-alias-lifetime", "foo"),
        "set03-cm10": (60, "pointer=2; type(=4", "unsupported-fortad-pointer-alias-lifetime", "allocatetata"),
        "set03-cm34": (85, "allocatable=1; pointer=2; type(=5; dimension=1", "unsupported-fortad-global-mutable-state", "allocatetoto"),
        "set03-lh013": (53, "type(=4; dimension=7", "runnable-ported", "function"),
    }
    prior = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path != CASE / "manifest.toml":
            prior.update(
                (case.get("component", "non-regressions"), case["queue_path"])
                for case in tomllib.loads(path.read_text()).get("case", [])
            )
    assert {(case["component"], case["queue_path"]) for case in result["cases"]}.isdisjoint(prior)

    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == [] and case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False and case["dependency_hints"] == []
        assert case["independent_oracle"]["status"] == "pass"
        assert ledger[(case["component"], case["queue_path"])]["status"] == classification
        for source in [case["source"], *case["references"]]:
            assert case["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
            assert case["exact_source_checks"][source]["strict"]["status"] == "pass"
            assert case["exact_source_checks"][source]["legacy"]["status"] == "pass"
        source_text = (ROOT / "upstream/tapenade" / case["source"]).read_text()
        assert re.search(
            rf"(?im)^\s*(?:(?:elemental|pure|recursive|impure)\s+)*"
            rf"(?:subroutine|function)\s+{re.escape(entry)}\b",
            source_text,
        )

    for case in result["cases"]:
        for mode in ("parser", "forward", "reverse"):
            assert case["modes"][mode]["tapenade"]["status"] == "pass"
    for case_id in ("set03-cm05", "set03-cm10", "set03-cm34"):
        case = next(case for case in result["cases"] if case["id"] == case_id)
        assert all(case["modes"][mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
        diagnostics = " ".join(case["modes"][mode]["fortad"].get("stderr", "") for mode in ("parser", "forward", "reverse"))
        assert "pointer" in diagnostics.lower() or "mutable state" in diagnostics.lower() or "allocation" in diagnostics.lower()
    lh013 = next(case for case in result["cases"] if case["id"] == "set03-lh013")
    assert all(lh013["modes"][mode]["fortad"]["status"] == "pass" for mode in ("parser", "forward", "reverse"))
    assert all(check["status"] == "pass" for mode in lh013["modes"].values() for check in mode["fortad"]["generated_syntax"].values())


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"cm05-pointer-result", "cm10-allocation-lifetime", "cm34-derived-allocation", "lh013-derived-affine"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
