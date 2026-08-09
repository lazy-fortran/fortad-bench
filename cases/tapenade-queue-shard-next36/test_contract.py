"""Contract and independent-oracle checks for next36."""

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
        "set06-v311": (32, "procedure=1; elemental=2; interface=2", "unsupported-fortad-invalid-generated-interface", "test"),
        "set06-v357": (32, "procedure=1; elemental=2; interface=2", "unsupported-fortad-invalid-generated-interface", "test"),
        "set11-vmp09": (32, "procedure=1; elemental=2; interface=2", "unsupported-fortad-invalid-generated-interface", "test"),
        "openmp-tinymgopt": (30, "dimension=10", "unsupported-fortad-active-io", "createandrun"),
    }
    expected_modes = {
        "set06-v311": {"parser": "pass", "forward": "pass", "reverse": "pass"},
        "set06-v357": {"parser": "pass", "forward": "pass", "reverse": "pass"},
        "set11-vmp09": {"parser": "pass", "forward": "pass", "reverse": "pass"},
        "openmp-tinymgopt": {"parser": "refused", "forward": "refused", "reverse": "refused"},
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
    expected_syntax = {
        "set06-v311": {"parser": "refused", "forward": "pass", "reverse": "pass"},
        "set06-v357": {"parser": "refused", "forward": "refused", "reverse": "refused"},
        "set11-vmp09": {"parser": "refused", "forward": "pass", "reverse": "pass"},
    }
    for name, modes in expected_syntax.items():
        for mode, status in modes.items():
            generated = by_id[name]["modes"][mode]["fortad"]["generated_syntax"]
            assert generated and all(item["status"] == status for item in generated.values())
    openmp = by_id["openmp-tinymgopt"]
    for mode in ("parser", "forward", "reverse"):
        assert "unsupported statement at line 51" in openmp["modes"][mode]["fortad"]["stderr"]
        assert openmp["modes"][mode]["fortad"]["generated"] == []


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
