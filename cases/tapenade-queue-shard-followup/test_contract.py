"""Independent contract and oracle checks for the follow-up shard."""

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
    assert result["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"]
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"]
    assert len(result["cases"]) == 4
    assert {case["id"] for case in result["cases"]} == {
        "set11-vmp06", "set04-lh159", "set11-vmp07", "set05-v193"
    }
    for case in result["cases"]:
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert set(case["modes"]) == {"parser", "forward", "reverse"}
        assert case["independent_oracle"]["status"] == "pass"
        assert case["classification"].startswith("unsupported-")
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == case["classification"]
        assert row["entry_point"] == case["entry_point"]
        assert row["modes"] == "parser|forward|reverse"
        assert "no-derivative-support-claim" in row["oracle"]
        assert row["tapenade_result"].startswith("pass-")
        assert "refusal" in row["fortad_result"] or "refused" in row["fortad_result"]
    vmp06 = next(case for case in result["cases"] if case["id"] == "set11-vmp06")
    assert all(mode["fortad"]["status"] == "refused" for mode in vmp06["modes"].values())
    assert "pointer association storage identity" in vmp06["modes"]["parser"]["fortad"]["stderr"]
    lh159 = next(case for case in result["cases"] if case["id"] == "set04-lh159")
    assert "module-level allocatable mutable state" in lh159["modes"]["parser"]["fortad"]["stderr"]
    vmp07 = next(case for case in result["cases"] if case["id"] == "set11-vmp07")
    assert "unsupported statement" in vmp07["modes"]["parser"]["fortad"]["stderr"]
    v193 = next(case for case in result["cases"] if case["id"] == "set05-v193")
    assert "unsupported statement" in v193["modes"]["parser"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(
        ["python3", str(CASE / "oracle.py")],
        capture_output=True,
        text=True,
        check=False,
    )
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"vmp06-add-node", "lh159-collection", "vmp07-dump-tree", "v193-find"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
