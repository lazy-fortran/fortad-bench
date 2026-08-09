"""Contract and independent-oracle checks for next26 wave6."""

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
        "set04-lh113": (42, "allocatable=1; type(=1; interface=1; dimension=5", "unsupported-fortad-global-mutable-state", "foo"),
        "set11-ompl07": (39, "dimension=13", "unsupported-fortad-openmp-directive", "stencil_nodefault"),
        "set05-v179": (37, "optional=7; dimension=3", "unsupported-fortad-active-io", "flio_uga"),
        "set06-v341": (34, "allocatable=1; type(=1; dimension=4", "unsupported-fortad-allocatable-derived-component", "top"),
    }
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
    prior = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path != CASE / "manifest.toml":
            prior.update((case.get("component", "non-regressions"), case["queue_path"]) for case in tomllib.loads(path.read_text(encoding="utf-8")).get("case", []))
    observed = {(case["component"], case["queue_path"]) for case in result["cases"]}
    assert observed.isdisjoint(prior)
    assert len(observed) == 4
    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["independent_oracle"]["status"] == "pass"
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification
        assert row["entry_point"] == entry
        assert row["modes"] == "parser|forward|reverse"
        assert row["tapenade_result"].startswith("pass-")
        assert "independent" in row["oracle"]
        for source in [case["source"], *case["references"]]:
            assert case["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
        assert all(mode["tapenade"]["status"] == "pass" for mode in case["modes"].values())
        assert all(mode["fortad"]["status"] == "refused" for mode in case["modes"].values())
    assert "module-level allocatable mutable state" in next(case for case in result["cases"] if case["id"] == "set04-lh113")["modes"]["parser"]["fortad"]["stderr"]
    assert "unsupported statement at line 5" in next(case for case in result["cases"] if case["id"] == "set11-ompl07")["modes"]["parser"]["fortad"]["stderr"]
    assert "unsupported statement at line 22" in next(case for case in result["cases"] if case["id"] == "set05-v179")["modes"]["parser"]["fortad"]["stderr"]
    assert "unsupported statement at line 1" in next(case for case in result["cases"] if case["id"] == "set06-v341")["modes"]["parser"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"lh113-foo-map", "ompl07-stencil-map", "v179-no-numeric-map", "v341-allocatable-boundary"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
