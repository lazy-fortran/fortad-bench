"""Contract and independent-oracle checks for next35."""

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
        "set06-v367": (38, "allocatable=1; type(=3", "unsupported-fortad-global-mutable-state", "foo"),
        "set06-v383": (37, "allocatable=2; dimension=3", "unsupported-fortad-logical-not", "multipl"),
        "set11-lh050": (33, "allocatable=2; iso_c_binding=1", "unsupported-fortad-invalid-generated-interface", "sum_magnitude"),
        "set04-v046": (32, "procedure=1; elemental=2; interface=2", "unsupported-fortad-invalid-generated-interface", "test"),
    }
    expected_modes = {
        "set06-v367": {"parser": "refused", "forward": "refused", "reverse": "refused"},
        "set06-v383": {"parser": "refused", "forward": "refused", "reverse": "refused"},
        "set11-lh050": {"parser": "pass", "forward": "pass", "reverse": "pass"},
        "set04-v046": {"parser": "pass", "forward": "pass", "reverse": "pass"},
    }
    assert result["shard_id"] == manifest["shard_id"]
    assert result["upstream_revision"] == manifest["upstream_revision"]
    assert result["fortad_revision"] == manifest["fortad_revision"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4
    prior = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path != CASE / "manifest.toml":
            data = tomllib.loads(path.read_text(encoding="utf-8"))
            prior.update((case.get("component", "non-regressions"), case["queue_path"]) for case in data.get("case", []))
    observed = {(case["component"], case["queue_path"]) for case in result["cases"]}
    assert observed.isdisjoint(prior)
    assert len(observed) == 4
    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["selection"] == "modern-feature-score-then-queue-order"
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
        assert "independent" in row["oracle"]
        for source in [case["source"], *case["references"]]:
            assert case["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
        for mode in ("parser", "forward", "reverse"):
            assert case["modes"][mode]["tapenade"]["status"] == "pass"
            assert case["modes"][mode]["fortad"]["status"] == expected_modes[case["id"]][mode]
    by_id = {case["id"]: case for case in result["cases"]}
    assert all("module-level allocatable mutable state" in by_id["set06-v367"]["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    assert all("unsupported operator '.not.'" in by_id["set06-v383"]["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    expected_syntax = {
        "set11-lh050": {"parser": "pass", "forward": "refused", "reverse": "refused"},
        "set04-v046": {"parser": "refused", "forward": "refused", "reverse": "pass"},
    }
    for name, modes in expected_syntax.items():
        for mode, status in modes.items():
            generated = by_id[name]["modes"][mode]["fortad"]["generated_syntax"]
            assert generated and all(item["status"] == status for item in generated.values())


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
