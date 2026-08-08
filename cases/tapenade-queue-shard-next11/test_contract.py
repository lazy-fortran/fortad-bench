"""Contract and independent-oracle checks for next11."""

from __future__ import annotations

import csv
import hashlib
import json
import re
import subprocess
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASE = Path(__file__).resolve().parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_contract() -> None:
    manifest = tomllib.loads((CASE / "manifest.toml").read_text())
    result = json.loads((CASE / "result.json").read_text())
    with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="") as stream:
        ledger = {(row["component"], row["path"]): row for row in csv.DictReader(stream)}
    assert result["shard_id"] == manifest["shard_id"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4
    expected = {
        "set03-cm31": (66, "pointer=3; type(=3", "unsupported-fortad-pointer-alias-lifetime", "top"),
        "set03-cm32": (66, "allocatable=1; pointer=2; type(=3", "unsupported-fortad-global-mutable-state", "top"),
        "set05-v194": (63, "dimension=21", "probed-fortad-generated-no-runtime-claim", "head"),
        "set06-v351": (62, "pointer=1; type(=2; procedure=2; interface/bind(c)/iso_c_binding=2; dimension=2", "unsupported-fortad-generic-intrinsic", "d1minval"),
    }
    selected = {case["queue_path"] for case in result["cases"]}
    assert len(selected) == 4
    prior = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path != CASE / "manifest.toml":
            prior.update(case["queue_path"] for case in tomllib.loads(path.read_text()).get("case", []))
    assert selected.isdisjoint(prior)
    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == [] and case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False and case["dependency_hints"] == []
        assert case["independent_oracle"]["status"] == "pass"
        assert ledger[(case["component"], case["queue_path"])] ["status"] == classification
        source = (ROOT / "upstream/tapenade" / case["source"]).read_text()
        assert re.search(rf"(?im)^\s*(?:subroutine|function)\s+{re.escape(entry)}\b", source)
        assert all(value["strict"]["status"] == "pass" and value["legacy"]["status"] == "pass" for value in case["exact_source_checks"].values())
        for engines in case["modes"].values():
            assert engines["tapenade"]["status"] == "pass"
    by_id = {case["id"]: case for case in result["cases"]}
    for cid in ("set03-cm31", "set03-cm32", "set06-v351"):
        for mode in ("parser", "forward", "reverse"):
            assert by_id[cid]["modes"][mode]["fortad"]["status"] == "refused"
    assert "pointer association storage identity" in by_id["set03-cm31"]["modes"]["parser"]["fortad"]["stderr"]
    assert "module-level allocatable mutable state" in by_id["set03-cm32"]["modes"]["parser"]["fortad"]["stderr"]
    assert "generic call 'minval'" in by_id["set06-v351"]["modes"]["parser"]["fortad"]["stderr"]
    assert by_id["set05-v194"]["modes"]["parser"]["fortad"]["status"] == "pass"
    assert by_id["set05-v194"]["modes"]["forward"]["fortad"]["status"] == "pass"
    assert by_id["set05-v194"]["modes"]["reverse"]["fortad"]["status"] == "refused"
    assert "infer Tapenade dependent" in by_id["set05-v194"]["modes"]["reverse"]["fortad"]["stderr"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"cm31-pointer-allocation", "cm32-allocatable-component", "v194-forall-primal", "v351-minval"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
