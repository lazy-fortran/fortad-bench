"""Contract and independent-oracle checks for next42."""

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


def test_contract() -> None:
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    result = json.loads((CASE / "result.json").read_text(encoding="utf-8"))
    with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="", encoding="utf-8") as stream:
        ledger = {(row["component"], row["path"]): row for row in csv.DictReader(stream)}
    expected = {
        "set03-lh068": (16, "type(=2", "unsupported-fortad-invalid-generated-interface", "top"),
        "set04-v002": (16, "type(=2", "unsupported-fortad-invalid-generated-interface", "dot_prod"),
        "set04-v003": (16, "type(=2", "unsupported-fortad-active-io", "test"),
        "set04-v012": (16, "type(=2", "unsupported-fortad-invalid-generated-interface", "t"),
    }
    assert result["shard_id"] == manifest["shard_id"]
    assert result["upstream_revision"] == manifest["upstream_revision"]
    assert result["fortad_revision"] == manifest["fortad_revision"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4
    observed = {(case["component"], case["queue_path"]) for case in result["cases"]}
    assert len(observed) == 4
    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["selection"] == "modern-feature-score-then-queue-order"
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["independent_oracle"]["status"] == "pass"
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification
        assert row["entry_point"] == entry
        assert row["modes"] == "parser|forward|reverse"
        assert "independent" in row["oracle"]
        for source in [case["source"], *case["references"]]:
            assert case["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
        for mode in ("parser", "forward", "reverse"):
            assert case["modes"][mode]["tapenade"]["status"] == "pass"
            assert all(item["status"] == "pass" for item in case["modes"][mode]["tapenade"]["generated_syntax"].values())
    lh068 = next(case for case in result["cases"] if case["id"] == "set03-lh068")
    assert all("could not infer Tapenade dependent" in lh068["modes"]["reverse"]["fortad"]["stderr"] for _ in [0])
    assert all(lh068["modes"][mode]["fortad"]["generated_syntax"]["probe_" + suffix + ".f90"]["status"] == "refused" for mode, suffix in (("parser", "p"), ("forward", "d")))
    v002 = next(case for case in result["cases"] if case["id"] == "set04-v002")
    assert all(v002["modes"][mode]["fortad"]["status"] == "pass" for mode in ("parser", "forward", "reverse"))
    assert all(all(item["status"] == "refused" for item in v002["modes"][mode]["fortad"]["generated_syntax"].values()) for mode in ("parser", "forward", "reverse"))
    v003 = next(case for case in result["cases"] if case["id"] == "set04-v003")
    assert all(v003["modes"][mode]["fortad"]["status"] == "refused" and v003["modes"][mode]["fortad"]["generated"] == [] for mode in ("parser", "forward", "reverse"))
    assert all("unsupported statement at line 15" in v003["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    v012 = next(case for case in result["cases"] if case["id"] == "set04-v012")
    assert "Cannot open module file" in v012["modes"]["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["stderr"]
    assert "could not infer Tapenade dependent" in v012["modes"]["reverse"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    assert set(values) == {case["oracle_case"] for case in manifest["case"]}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
