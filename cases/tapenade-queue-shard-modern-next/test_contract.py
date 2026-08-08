"""Contract and independent-oracle checks for the modern-next shard."""

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
        "set06-v344": (320, "pointer=12; associate=4; type(=13", "unsupported-fortad-pointer-ownership"),
        "set12-f03typf02": (270, "abstract=5; select type=1; class(=6; type(=2; procedure=5", "unsupported-fortad-abstract-polymorphic-context"),
        "set12-mvo35": (248, "select type=1; class(=6; pointer=3; derived/type ::=1; type(=2; procedure=2; interface/bind(c)/iso_c_binding=10", "unsupported-fortad-polymorphic-procedure-pointer"),
        "set04-lh140": (194, "pointer=8; derived/type ::=1; type(=9", "unsupported-fortad-pointer-alias-lifetime"),
    }
    assert {case["id"] for case in result["cases"]} == set(expected)
    for case in result["cases"]:
        score, features, classification = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"]) == (score, features, classification)
        assert case["selection"] == "modern-feature-score-then-queue-order"
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert case["probe_status"] == "probed"
        assert set(case["modes"]) == {"parser", "forward", "reverse"}
        assert case["independent_oracle"]["status"] == "pass"
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification
        assert row["entry_point"] == case["entry_point"]
        assert row["modes"] == "parser|forward|reverse"
        assert "no-derivative-support-claim" in row["oracle"]
        assert row["tapenade_result"].startswith("pass-")
        assert "refused" in row["fortad_result"]
        for mode in case["modes"].values():
            assert mode["tapenade"]["status"] == "pass"
            assert mode["fortad"]["status"] == "refused"
    for case_id, needle in {
        "set06-v344": "pointer association storage identity",
        "set12-f03typf02": "Unexpected token",
        "set12-mvo35": "unsupported statement at line 95",
        "set04-lh140": "pointer association storage identity",
    }.items():
        case = next(item for item in result["cases"] if item["id"] == case_id)
        assert needle in case["modes"]["parser"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v344-foo", "f03typf02-foo", "mvo35-foo", "lh140-compute"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
