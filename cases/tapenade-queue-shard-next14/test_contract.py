"""Contract and independent-oracle checks for next14."""

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
    assert manifest["current_queue_sha256"] == result["current_queue_sha256"]
    assert manifest["current_batch_sha256"] == result["current_batch_sha256"]
    assert len(result["cases"]) == 4

    expected = {
        "set04-v004": (50, "type(=4; procedure=1; interface=2", "unsupported-fortad-global-mutable-state", "test"),
        "set07-v531": (48, "pointer=2; type(=1; dimension=4", "unsupported-fortad-generic-intrinsic", "foo"),
        "set04-lh108": (47, "allocatable=1; pointer=1; type(=2; dimension=1", "unsupported-fortad-global-mutable-state", "top"),
        "set04-v048": (32, "procedure=1; elemental/pure/final=2; interface/bind(c)/iso_c_binding=2", "runnable-ported", "twice_real"),
    }
    selected = {case["queue_path"] for case in result["cases"]}
    assert len(selected) == 4
    prior = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path != CASE / "manifest.toml":
            prior.update(
                (case.get("component", "non-regressions"), case["queue_path"])
                for case in tomllib.loads(path.read_text()).get("case", [])
            )
    assert {(case["component"], case["queue_path"]) for case in result["cases"]}.isdisjoint(prior)

    by_id = {case["id"]: case for case in result["cases"]}
    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == [] and case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False and case["dependency_hints"] == []
        assert case["independent_oracle"]["status"] == "pass"
        assert ledger[(case["component"], case["queue_path"])] ["status"] == classification
        for source in [case["source"], *case["references"]]:
            assert case["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
            assert case["exact_source_checks"][source]["strict"]["status"] == "pass"
            assert case["exact_source_checks"][source]["legacy"]["status"] == "pass"
        assert re.search(rf"(?im)^\s*(?:(?:elemental|pure|recursive|impure)\s+)*(?:subroutine|function)\s+{re.escape(entry)}\b", (ROOT / "upstream/tapenade" / case["source"]).read_text())
        for mode in ("parser", "forward", "reverse"):
            assert case["modes"][mode]["tapenade"]["status"] == "pass"

    for case_id in ("set04-v004", "set04-lh108"):
        for mode in ("parser", "forward", "reverse"):
            assert by_id[case_id]["modes"][mode]["fortad"]["status"] == "refused"
    assert by_id["set07-v531"]["modes"]["parser"]["fortad"]["status"] == "pass"
    assert by_id["set07-v531"]["modes"]["forward"]["fortad"]["status"] == "refused"
    assert by_id["set07-v531"]["modes"]["reverse"]["fortad"]["status"] == "refused"
    assert "module-level allocatable mutable state" in by_id["set04-lh108"]["modes"]["parser"]["fortad"]["stderr"]
    assert "unsupported active global state" in by_id["set04-v004"]["modes"]["parser"]["fortad"]["stderr"]
    assert "no derivative rule for 'size'" in by_id["set07-v531"]["modes"]["forward"]["fortad"]["stderr"]
    assert "could not infer Tapenade dependent" in by_id["set07-v531"]["modes"]["reverse"]["fortad"]["stderr"]
    for mode in ("parser", "forward", "reverse"):
        for engine in ("fortad", "tapenade"):
            assert by_id["set04-v048"]["modes"][mode][engine]["status"] == "pass"
            assert all(check["status"] == "pass" for check in by_id["set04-v048"]["modes"][mode][engine]["generated_syntax"].values())


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v004-derived-vector", "v531-pointer-size", "lh108-allocatable-state", "v048-elemental-generic"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
