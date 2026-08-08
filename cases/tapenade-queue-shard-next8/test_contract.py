"""Contract and independent-oracle checks for the next8 shard."""

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
FULL_HASH = re.compile(r"^[0-9a-f]{64}$")


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
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert all(FULL_HASH.fullmatch(result[key]) for key in ("selection_queue_sha256", "selection_batch_sha256", "current_queue_sha256", "current_batch_sha256"))
    assert len(result["cases"]) == 4

    expected = {
        "set03-cmv07": (92, "allocatable=4; type(=3; dimension=4", "unsupported-fortad-global-mutable-state", "intini"),
        "set10-lh234": (86, "pointer=3; associate=1; type(=4", "unsupported-fortad-derived-type-component", "head"),
        "set06-v237": (84, "pointer=5; type(=1; dimension=2", "expected-refusal", "bcfarfieldadj"),
        "set03-cm30": (82, "pointer=3; type(=5", "unsupported-fortad-pointer-alias-lifetime", "top"),
    }
    assert {case["id"] for case in result["cases"]} == set(expected)
    selected_paths = {case["queue_path"] for case in result["cases"]}
    assert len(selected_paths) == 4
    previously_selected = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path == CASE / "manifest.toml":
            continue
        previous = tomllib.loads(path.read_text(encoding="utf-8"))
        previously_selected.update(case["queue_path"] for case in previous.get("case", []))
    assert selected_paths.isdisjoint(previously_selected)

    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["selection"] == "modern-feature-score-then-queue-order-real-source-entry"
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == [] and case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False and case["dependency_hints"] == []
        assert case["probe_status"] == "probed"
        assert case["independent_oracle"]["status"] == "pass"
        source_text = (ROOT / "upstream" / "tapenade" / case["source"]).read_text(encoding="utf-8")
        assert re.search(rf"(?im)^\s*(?:recursive\s+|pure\s+|elemental\s+|impure\s+)*(?:subroutine|function)\s+{re.escape(entry)}\b", source_text)
        assert all(set(value) == {"strict", "legacy"} for value in case["exact_source_checks"].values())
        assert all(value["strict"]["status"] == "pass" and value["legacy"]["status"] == "pass" for value in case["exact_source_checks"].values())
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification
        assert row["entry_point"] == entry
        assert row["modes"] == "parser|forward|reverse"
        assert "no-derivative-support-claim" in row["oracle"]
        for engines in case["modes"].values():
            assert engines["tapenade"]["status"] == "pass"

    by_id = {case["id"]: case for case in result["cases"]}
    assert all(by_id["set03-cmv07"]["modes"][mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
    assert "module-level allocatable mutable state" in by_id["set03-cmv07"]["modes"]["parser"]["fortad"]["stderr"]
    assert by_id["set10-lh234"]["modes"]["parser"]["fortad"]["status"] == "pass"
    assert by_id["set10-lh234"]["modes"]["forward"]["fortad"]["status"] == "refused"
    assert "active derived object 'LIST'" in by_id["set10-lh234"]["modes"]["forward"]["fortad"]["stderr"]
    assert by_id["set10-lh234"]["modes"]["reverse"]["fortad"]["status"] == "refused"
    assert "could not infer Tapenade dependent" in by_id["set10-lh234"]["modes"]["reverse"]["fortad"]["stderr"]
    assert by_id["set06-v237"]["modes"]["parser"]["fortad"]["status"] == "pass"
    assert by_id["set06-v237"]["modes"]["forward"]["fortad"]["status"] == "pass"
    assert by_id["set06-v237"]["modes"]["reverse"]["fortad"]["status"] == "refused"
    assert "could not infer Tapenade dependent" in by_id["set06-v237"]["modes"]["reverse"]["fortad"]["stderr"]
    assert all(by_id["set03-cm30"]["modes"][mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
    assert "pointer association storage identity" in by_id["set03-cm30"]["modes"]["parser"]["fortad"]["stderr"]

    for relative in (manifest["queue_file"], manifest["batch_file"]):
        rows = [json.loads(line) for line in (ROOT / relative).read_text(encoding="utf-8").splitlines() if line]
        assert not selected_paths.intersection(row["path"] for row in rows)


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"cm30-pointer-lifetime", "cmv07-module-allocation", "lh234-linked-list", "v237-explicit-state"}
    assert all(value["status"] == "pass" for value in values.values())
    assert values["lh234-linked-list"]["derivative"]["status"] == "verified"
    assert values["v237-explicit-state"]["derivative"]["status"] == "verified"
    assert values["cm30-pointer-lifetime"]["refusal"]["status"] == "expected"


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
