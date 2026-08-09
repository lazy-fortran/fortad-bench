"""Contract and independent-oracle checks for next38."""

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
        "set10-lh215": (24, "dimension=8", "unsupported-fortad-invalid-generated-interface", "foo"),
        "set10-lh216": (24, "dimension=8", "unsupported-fortad-generic-intrinsic", "foo"),
        "set12-mvo11": (24, "interface=3; dimension=3", "unsupported-fortad-invalid-generated-interface", "bug"),
        "set07-v472": (22, "interface=2; dimension=4", "unsupported-fortad-invalid-generated-interface", "compute"),
    }
    expected_fortad = {
        "set10-lh215": {"parser": "pass", "forward": "pass", "reverse": "pass"},
        "set10-lh216": {"parser": "pass", "forward": "refused", "reverse": "refused"},
        "set12-mvo11": {"parser": "refused", "forward": "refused", "reverse": "refused"},
        "set07-v472": {"parser": "pass", "forward": "pass", "reverse": "pass"},
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
            assert case["modes"][mode]["fortad"]["status"] == expected_fortad[case["id"]][mode]
    by_id = {case["id"]: case for case in result["cases"]}
    assert by_id["set10-lh215"]["modes"]["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["status"] == "pass"
    assert by_id["set10-lh215"]["modes"]["forward"]["fortad"]["generated_syntax"]["probe_d.f90"]["status"] == "pass"
    assert by_id["set10-lh215"]["modes"]["reverse"]["fortad"]["generated_syntax"]["probe_b.f90"]["status"] == "refused"
    assert "must be an array" in by_id["set10-lh215"]["modes"]["reverse"]["fortad"]["generated_syntax"]["probe_b.f90"]["stderr"]
    assert "Incompatible ranks" in by_id["set10-lh215"]["modes"]["reverse"]["fortad"]["generated_syntax"]["probe_b.f90"]["stderr"]
    assert "no derivative rule for 'SPREAD'" in by_id["set10-lh216"]["modes"]["forward"]["fortad"]["stderr"]
    assert "could not infer Tapenade dependent" in by_id["set10-lh216"]["modes"]["reverse"]["fortad"]["stderr"]
    assert all("unsupported statement at line 12" in by_id["set12-mvo11"]["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    for mode, product in (("parser", "probe_p.f90"), ("forward", "probe_d.f90"), ("reverse", "probe_b.f90")):
        assert by_id["set07-v472"]["modes"][mode]["fortad"]["generated_syntax"][product]["status"] == "refused"
    assert "module global accumulator" in by_id["set07-v472"]["closure"]


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
