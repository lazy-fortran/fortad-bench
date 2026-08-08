"""Contract and independent-oracle checks for the modern follow-up shard."""

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
    expected = {
        "set04-v030": (210, "type(=15; procedure=5; interface/bind(c)/iso_c_binding=10", "unsupported-fortad-derived-type-component"),
        "set07-v534": (165, "pointer=7; interface/bind(c)/iso_c_binding=2; dimension=19", "unsupported-fortad-pointer-ownership"),
        "set12-mvo34": (165, "abstract=1; class(=5; pointer=1; type(=1; procedure=1; interface/bind(c)/iso_c_binding=7", "unsupported-fortad-polymorphic-procedure-pointer"),
        "set07-v535": (159, "pointer=7; interface/bind(c)/iso_c_binding=2; dimension=17", "unsupported-fortad-pointer-ownership"),
    }
    assert result["shard_id"] == manifest["shard_id"]
    assert result["upstream_revision"] == manifest["upstream_revision"]
    assert result["fortad_revision"] == manifest["fortad_revision"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert {case["id"] for case in result["cases"]} == set(expected)
    for case in result["cases"]:
        score, features, classification = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"]) == (score, features, classification)
        assert case["selection"] == "modern-feature-score-then-queue-order"
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
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
        if case["id"] == "set04-v030":
            assert case["modes"]["parser"]["fortad"]["status"] == "pass"
            assert case["modes"]["forward"]["fortad"]["status"] == "refused"
            assert case["modes"]["reverse"]["fortad"]["status"] == "refused"
            assert "active derived object 'A' must name a real component" in case["modes"]["forward"]["fortad"]["stderr"]
        else:
            assert all(mode["fortad"]["status"] == "refused" for mode in case["modes"].values())
    assert "pointer association storage identity" in next(case for case in result["cases"] if case["id"] == "set07-v534")["modes"]["parser"]["fortad"]["stderr"]
    assert "unsupported statement at line 22" in next(case for case in result["cases"] if case["id"] == "set12-mvo34")["modes"]["parser"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v030-interval-addition", "v534-testallocs", "mvo34-type-set-func", "v535-testallocs"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
