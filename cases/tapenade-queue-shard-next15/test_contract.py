"""Contract and independent-oracle checks for next15."""

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
        "set05-v077": (101, "procedure=7; interface=9", "unsupported-fortad-invalid-generated-interface", "add_logicals"),
        "set11-vpf20": (92, "type(=7; procedure=2; interface=4", "unsupported-fortad-derived-type-component", "some_type2_minus"),
        "set10-lh230": (88, "pointer=5; dimension=6", "unsupported-fortad-pointer-alias-lifetime", "foo"),
        "set10-lh232": (88, "pointer=5; dimension=6", "unsupported-fortad-pointer-alias-lifetime", "bar"),
    }
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
        source_text = (ROOT / "upstream/tapenade" / case["source"]).read_text()
        assert re.search(
            rf"(?im)^\s*(?:(?:elemental|pure|recursive|impure)\s+)*"
            rf"(?:subroutine|function)\s+{re.escape(case['entry_point'])}\b",
            source_text,
        )
    for mode in ("parser", "forward", "reverse"):
        assert by_id["set05-v077"]["modes"][mode]["tapenade"]["status"] == "pass"
        assert by_id["set11-vpf20"]["modes"][mode]["tapenade"]["status"] == "pass"
        assert by_id["set10-lh230"]["modes"][mode]["tapenade"]["status"] == "pass"
        assert by_id["set10-lh232"]["modes"][mode]["tapenade"]["status"] == "pass"
    assert all(check["status"] == "pass" for check in by_id["set05-v077"]["modes"]["parser"]["fortad"]["generated_syntax"].values())
    for mode in ("forward", "reverse"):
        assert by_id["set05-v077"]["modes"][mode]["fortad"]["status"] == "pass"
        assert any(check["status"] == "refused" for check in by_id["set05-v077"]["modes"][mode]["fortad"]["generated_syntax"].values())
    assert by_id["set11-vpf20"]["modes"]["parser"]["fortad"]["status"] == "pass"
    for mode in ("forward", "reverse"):
        assert by_id["set11-vpf20"]["modes"][mode]["fortad"]["status"] == "refused"
    for case_id, line in (("set11-vpf20", "active derived object"), ("set10-lh230", "pointer association storage identity"), ("set10-lh232", "pointer association storage identity")):
        assert line in " ".join(by_id[case_id]["modes"][mode]["fortad"].get("stderr", "") for mode in ("parser", "forward", "reverse"))
    for case_id in ("set10-lh230", "set10-lh232"):
        assert all(by_id[case_id]["modes"][mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
    assert "REAL" in by_id["set05-v077"]["closure"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"v077-logical-operator", "vpf20-nested-derived", "lh230-common-pointer", "lh232-common-pointer-call-tree"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
