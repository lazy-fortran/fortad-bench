"""Contract and independent-oracle checks for next32."""

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
        "set03-lh094": (20, "type(=1; dimension=4", "unsupported-fortad-derived-type-component", "top"),
        "set04-ptr09": (20, "pointer=1; dimension=2", "unsupported-fortad-pointer-alias-lifetime", "test"),
        "set06-v222": (20, "interface/bind(c)/iso_c_binding=4", "unsupported-fortad-invalid-generated-interface", "test1"),
        "set07-v436": (20, "pointer=1; dimension=2", "unsupported-fortad-derived-type-component", "test"),
    }
    fortad = {case_id: {"parser": "refused", "forward": "refused", "reverse": "refused"} for case_id in expected}
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
        assert case["selection"] == "modern-feature-score-then-queue-order"
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["classification"] != "unsupported-invalid-upstream-fortran"
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
            assert case["modes"][mode]["fortad"]["status"] == fortad[case["id"]][mode]
    by_id = {case["id"]: case for case in result["cases"]}
    assert "unsupported statement at line 1" in by_id["set03-lh094"]["modes"]["parser"]["fortad"]["stderr"]
    assert "pointer association storage identity is not tracked" in by_id["set04-ptr09"]["modes"]["parser"]["fortad"]["stderr"]
    assert "unsupported statement at line 25" in by_id["set06-v222"]["modes"]["parser"]["fortad"]["stderr"]
    assert "unsupported statement at line 1" in by_id["set07-v436"]["modes"]["parser"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {case["oracle_case"] for case in tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))["case"]}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
