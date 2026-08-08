"""Contract and independent-oracle checks for next23."""

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
        "set04-v035": (47, "allocatable=1; dimension=11", "unsupported-fortad-global-mutable-state"),
        "set03-cm35": (44, "pointer=2; type(=2", "unsupported-fortad-pointer-alias-lifetime"),
        "set03-cmv01": (44, "pointer=2; type(=2", "unsupported-fortad-invalid-generated-interface"),
        "set06-v307": (44, "pointer=2; optional=1; dimension=4", "unsupported-fortad-invalid-generated-interface"),
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
        score, features, classification = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"]) == (score, features, classification)
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["independent_oracle"]["status"] == "pass"
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification
        assert row["entry_point"] == case["entry_point"]
        assert row["modes"] == "parser|forward|reverse"
        assert row["tapenade_result"].startswith("pass-")
        assert "independent" in row["oracle"]
        for source in [case["source"], *case["references"]]:
            assert case["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
        if case["id"] != "set06-v307":
            assert all(
                check["status"] == "pass"
                for mode in case["modes"].values()
                for check in mode["tapenade"]["generated_syntax"].values()
            )
    v035 = next(case for case in result["cases"] if case["id"] == "set04-v035")
    assert all(mode["fortad"]["status"] == "refused" for mode in v035["modes"].values())
    assert "module-level allocatable mutable state" in v035["modes"]["parser"]["fortad"]["stderr"]
    cm35 = next(case for case in result["cases"] if case["id"] == "set03-cm35")
    assert all(mode["fortad"]["status"] == "refused" for mode in cm35["modes"].values())
    assert "TARGET alias storage identity is not tracked" in cm35["modes"]["parser"]["fortad"]["stderr"]
    cmv01 = next(case for case in result["cases"] if case["id"] == "set03-cmv01")
    assert cmv01["modes"]["parser"]["fortad"]["status"] == "pass"
    assert cmv01["modes"]["forward"]["fortad"]["status"] == "pass"
    assert all(
        check["status"] == "refused"
        for mode in (cmv01["modes"]["parser"], cmv01["modes"]["forward"])
        for check in mode["fortad"]["generated_syntax"].values()
    )
    assert cmv01["modes"]["reverse"]["fortad"]["status"] == "refused"
    assert "could not infer Tapenade dependent" in cmv01["modes"]["reverse"]["fortad"]["stderr"]
    v307 = next(case for case in result["cases"] if case["id"] == "set06-v307")
    assert all(mode["fortad"]["status"] == "pass" for mode in v307["modes"].values())
    assert all(
        check["status"] == "refused"
        for mode in v307["modes"].values()
        for check in mode["fortad"]["generated_syntax"].values()
    )
    assert v307["modes"]["parser"]["tapenade"]["generated_syntax"]["probe_p.f90"]["status"] == "refused"


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {case["oracle_case"] for case in tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))["case"]}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
