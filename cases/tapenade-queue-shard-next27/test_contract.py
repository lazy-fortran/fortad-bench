"""Contract and independent-oracle checks for next27."""

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
        "set07-v434": (34, "pointer=2; dimension=2", "unsupported-fortad-pointer-alias-lifetime", "test1"),
        "set07-v542": (34, "allocatable=2; dimension=2", "unsupported-fortad-allocatable-lifetime", "test"),
        "set04-lh107": (33, "allocatable=1; type(=2; dimension=1", "unsupported-fortad-global-mutable-state", "foo"),
        "set05-v152": (32, "allocatable=1; pointer=1; optional=1", "expected-refusal", "test"),
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
        assert "independent" in row["oracle"]
        for source in [case["source"], *case["references"]]:
            assert case["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
        assert all(mode["tapenade"]["status"] == "pass" for mode in case["modes"].values())
    by_id = {case["id"]: case for case in result["cases"]}
    assert all(mode["fortad"]["status"] == "refused" for mode in by_id["set07-v434"]["modes"].values())
    assert "pointer association storage identity" in by_id["set07-v434"]["modes"]["parser"]["fortad"]["stderr"]
    assert by_id["set07-v542"]["modes"]["parser"]["fortad"]["status"] == "pass"
    assert by_id["set07-v542"]["modes"]["forward"]["fortad"]["status"] == "pass"
    assert by_id["set07-v542"]["modes"]["reverse"]["fortad"]["status"] == "refused"
    assert "--dep" in by_id["set07-v542"]["modes"]["reverse"]["fortad"]["command"]
    assert "explicit deallocate of 'x'" in by_id["set07-v542"]["modes"]["reverse"]["fortad"]["stderr"]
    assert all(mode["fortad"]["status"] == "refused" for mode in by_id["set04-lh107"]["modes"].values())
    assert "module-level allocatable mutable state" in by_id["set04-lh107"]["modes"]["parser"]["fortad"]["stderr"]
    assert all(mode["fortad"]["status"] == "pass" for mode in by_id["set05-v152"]["modes"].values())
    assert "--dep" in by_id["set05-v152"]["modes"]["reverse"]["fortad"]["command"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v434-test1-where", "v542-test-square", "lh107-foo-map", "v152-no-numeric-map"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
