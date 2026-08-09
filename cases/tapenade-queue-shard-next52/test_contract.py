"""Contract and independent-oracle checks for next52."""
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
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def prior_cases() -> set[tuple[str, str]]:
    keys = set()
    for path in ROOT.glob("cases/tapenade-queue-shard-*/manifest.toml"):
        if path == CASE / "manifest.toml":
            continue
        data = tomllib.loads(path.read_text(encoding="utf-8"))
        keys.update((item["component"], item["queue_path"]) for item in data.get("case", []))
    return keys


def test_contract() -> None:
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    result = json.loads((CASE / "result.json").read_text(encoding="utf-8"))
    with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="", encoding="utf-8") as stream:
        ledger = {(row["component"], row["path"]): row for row in csv.DictReader(stream)}
    assert result["shard_id"] == manifest["shard_id"]
    for key in ("upstream_revision", "fortad_revision", "fortfront_revision", "selection_queue_sha256", "selection_batch_sha256"):
        assert result[key] == manifest[key]
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(manifest["case"]) == len(result["cases"]) == 48
    observed = {(item["component"], item["queue_path"]) for item in result["cases"]}
    assert len(observed) == 48 and observed.isdisjoint(prior_cases())
    for selected, item in zip(manifest["case"], result["cases"]):
        assert (selected["component"], selected["queue_path"]) == (item["component"], item["queue_path"])
        assert item["selection"] == "modern-feature-score-then-queue-order"
        assert item["compiler_status"] == "compiler-clean"
        assert item["compiler_missing_source_files"] == [] and item["compiler_extra_source_files"] == []
        assert item["dependency_risk"] is False and item["independent_oracle"]["status"] == "pass"
        row = ledger[(item["component"], item["queue_path"])]
        assert row["status"] == item["classification"]
        assert row["entry_point"] == item["entry_point"]
        assert row["modes"] == "parser|forward|reverse" and "independent" in row["oracle"]
        for source in [item["source"], *item["references"]]:
            assert item["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
        for mode in ("parser", "forward", "reverse"):
            assert item["modes"][mode]["tapenade"]["status"] == "pass"
            fortad = item["modes"][mode]["fortad"]
            assert fortad["status"] in {"pass", "refused"}
            if item["classification"] == "probed-fortad-generated-no-runtime-claim":
                assert fortad["status"] == "pass" and fortad["generated"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    assert set(values) == {item["oracle_case"] for item in manifest["case"]}
    assert all(item["status"] == "pass" for item in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
