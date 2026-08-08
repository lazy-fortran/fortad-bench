"""Contract and independent-oracle checks for next25."""

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
        "set06-v346": (63, "pointer=2; procedure=2; interface=2; dimension=3", "unsupported-fortad-pointer-alias-lifetime", "bar"),
        "set07-v397": (55, "pointer=1; procedure=2; interface=5", "unsupported-fortad-procedure-call-actual", "head"),
        "set11-vpf15": (47, "type(=3; procedure=1; interface=3", "unsupported-fortad-invalid-generated-interface", "foo"),
        "set03-cm23": (42, "allocatable=3", "unsupported-fortad-procedure-call-actual", "top"),
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
    v346 = next(case for case in result["cases"] if case["id"] == "set06-v346")
    assert all(mode["fortad"]["status"] == "refused" for mode in v346["modes"].values())
    assert "pointer association storage identity" in v346["modes"]["parser"]["fortad"]["stderr"]
    v397 = next(case for case in result["cases"] if case["id"] == "set07-v397")
    assert v397["modes"]["parser"]["fortad"]["status"] == "pass"
    assert all(v397["modes"][mode]["fortad"]["status"] == "refused" for mode in ("forward", "reverse"))
    assert "no derivative rule" in v397["modes"]["forward"]["fortad"]["stderr"]
    vpf15 = next(case for case in result["cases"] if case["id"] == "set11-vpf15")
    assert all(mode["fortad"]["status"] == "pass" for mode in vpf15["modes"].values())
    assert vpf15["modes"]["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["status"] == "pass"
    assert vpf15["modes"]["forward"]["fortad"]["generated_syntax"]["probe_d.f90"]["status"] == "pass"
    assert vpf15["modes"]["reverse"]["fortad"]["generated_syntax"]["probe_b.f90"]["status"] == "refused"
    cm23 = next(case for case in result["cases"] if case["id"] == "set03-cm23")
    assert all(mode["fortad"]["status"] == "refused" for mode in cm23["modes"].values())
    assert "allocatable storage" in cm23["modes"]["parser"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v346-generic-pointer-boundary", "v397-generic-dispatch-map", "vpf15-overloaded-derived-difference", "cm23-allocatable-call-map"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
