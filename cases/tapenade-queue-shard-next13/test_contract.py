"""Contract and independent-oracle checks for next13."""

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
    assert manifest["current_queue_sha256"] == result["current_queue_sha256"]
    assert manifest["current_batch_sha256"] == result["current_batch_sha256"]
    assert len(result["cases"]) == 4
    expected = {
        "set06-v364": (56, "pointer=2; associate=1; type(=2", "unsupported-fortad-pointer-alias-lifetime", "test"),
        "set04-lh112": (55, "pointer=1; type(=4; dimension=3", "unsupported-fortad-pointer-alias-lifetime", "top"),
        "set03-lh051": (52, "pointer=3; interface=2", "unsupported-fortad-pointer-alias-lifetime", "top"),
        "set03-cm25": (50, "pointer=3; type(=1", "unsupported-fortad-derived-component-allocation", "top"),
    }
    selected = {case["queue_path"] for case in result["cases"]}
    assert len(selected) == 4
    prior = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path != CASE / "manifest.toml":
            prior.update(case["queue_path"] for case in tomllib.loads(path.read_text()).get("case", []))
    assert selected.isdisjoint(prior)
    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == [] and case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False and case["dependency_hints"] == []
        assert case["independent_oracle"]["status"] == "pass"
        assert ledger[(case["component"], case["queue_path"])] ["status"] == classification
        source = (ROOT / "upstream/tapenade" / case["source"]).read_text()
        assert re.search(rf"(?im)^\s*(?:subroutine|function)\s+{re.escape(entry)}\b", source)
        assert all(value["strict"]["status"] == "pass" and value["legacy"]["status"] == "pass" for value in case["exact_source_checks"].values())
        assert case["source_reference_sha256"]
        for engines in case["modes"].values():
            assert engines["tapenade"]["status"] == "pass"
    by_id = {case["id"]: case for case in result["cases"]}
    for mode in ("parser", "forward", "reverse"):
        assert by_id["set06-v364"]["modes"][mode]["fortad"]["status"] == "refused"
        assert by_id["set04-lh112"]["modes"][mode]["fortad"]["status"] == "refused"
        assert by_id["set03-lh051"]["modes"][mode]["fortad"]["status"] == "refused"
    assert by_id["set03-cm25"]["modes"]["parser"]["fortad"]["status"] == "pass"
    assert by_id["set03-cm25"]["modes"]["forward"]["fortad"]["status"] == "refused"
    assert by_id["set03-cm25"]["modes"]["reverse"]["fortad"]["status"] == "refused"
    assert "pointer association storage identity" in by_id["set06-v364"]["modes"]["parser"]["fortad"]["stderr"]
    assert "TARGET alias storage identity" in by_id["set04-lh112"]["modes"]["parser"]["fortad"]["stderr"]
    assert "TARGET alias storage identity" in by_id["set03-lh051"]["modes"]["parser"]["fortad"]["stderr"]
    assert "no derivative rule for the call to 'allocateX'" in by_id["set03-cm25"]["modes"]["forward"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v364-linked-list", "lh112-active-prefix", "lh051-target-alias", "cm25-component-allocation"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
