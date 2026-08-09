"""Contract and independent-oracle checks for next37."""

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
        "set05-v182": (32, "procedure=1; generic=1; interface=2", "unsupported-fortad-procedure-call-actual", "s"),
        "set07-v499": (30, "procedure=1; defined-assignment=1; interface=2", "unsupported-fortad-active-io", "chars_to_integer"),
        "set10-lh233": (24, "allocatable=1; module-state=1; array-section=2", "unsupported-fortad-program-unit-layout", "l2h1h2error"),
        "set11-vpf23": (24, "allocatable=1; dummy=2; external-call=1", "unsupported-fortad-procedure-call-actual", "costlast"),
    }
    expected_fortad = {
        "set05-v182": {"parser": "pass", "forward": "refused", "reverse": "refused"},
        "set07-v499": {"parser": "refused", "forward": "refused", "reverse": "refused"},
        "set10-lh233": {"parser": "refused", "forward": "refused", "reverse": "refused"},
        "set11-vpf23": {"parser": "refused", "forward": "refused", "reverse": "refused"},
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
    assert by_id["set05-v182"]["modes"]["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["status"] == "pass"
    assert "no derivative rule for the call to 'func'" in by_id["set05-v182"]["modes"]["forward"]["fortad"]["stderr"]
    assert "could not infer Tapenade dependent" in by_id["set05-v182"]["modes"]["reverse"]["fortad"]["stderr"]
    assert all("unsupported statement at line 13" in by_id["set07-v499"]["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    assert all("END PROGRAM redmhd" in by_id["set10-lh233"]["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    assert all("unsupported statement at line 19" in by_id["set11-vpf23"]["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))


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
