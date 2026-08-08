"""Contract and independent-oracle checks for the next7 shard."""

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
FULL_HASH = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_contract() -> None:
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    result = json.loads((CASE / "result.json").read_text(encoding="utf-8"))
    with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="", encoding="utf-8") as stream:
        ledger = {(row["component"], row["path"]): row for row in csv.DictReader(stream)}

    assert result["shard_id"] == manifest["shard_id"]
    assert result["upstream_revision"] == manifest["upstream_revision"]
    assert result["fortad_revision"] == manifest["fortad_revision"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"]
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"]
    assert result["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert all(FULL_HASH.fullmatch(result[key]) for key in ("selection_queue_sha256", "selection_batch_sha256", "current_queue_sha256", "current_batch_sha256"))
    assert len(result["cases"]) == 4

    expected = {
        "set03-cm07": (96, "pointer=4; type(=5", "unsupported-fortad-pointer-alias-lifetime"),
        "set04-v006": (94, "type(=5; procedure=3; interface=6", "unsupported-fortad-derived-type-component"),
        "set11-v006": (94, "type(=5; procedure=3; interface=6", "unsupported-fortad-derived-type-component"),
        "set03-cm09": (90, "pointer=3; type(=6", "unsupported-fortad-pointer-alias-lifetime"),
    }
    assert {case["id"] for case in result["cases"]} == set(expected)
    selected_paths = {case["queue_path"] for case in result["cases"]}
    assert len(selected_paths) == 4
    previously_selected = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path == CASE / "manifest.toml":
            continue
        previous = tomllib.loads(path.read_text(encoding="utf-8"))
        previously_selected.update(case["queue_path"] for case in previous.get("case", []))
    assert selected_paths.isdisjoint(previously_selected)

    for case in result["cases"]:
        score, features, classification = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"]) == (score, features, classification)
        assert case["selection"] == "modern-feature-score-then-queue-order-real-source-entry"
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["probe_status"] in {"probed", "pass"}
        assert case["fortad_revision"] == manifest["fortad_revision"]
        assert case["independent_oracle"]["status"] == "pass"
        source_text = (ROOT / "upstream" / "tapenade" / case["source"]).read_text(encoding="utf-8")
        assert re.search(
            rf"(?im)^\s*(?:recursive\s+|pure\s+|elemental\s+|impure\s+)*(?:subroutine|function)\s+{re.escape(case['entry_point'])}\b",
            source_text,
        )
        assert all(set(value) == {"strict", "legacy"} for value in case["exact_source_checks"].values())
        assert all(
            value["strict"]["status"] == "pass" and value["legacy"]["status"] == "pass"
            for value in case["exact_source_checks"].values()
        )
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification
        assert row["entry_point"] == case["entry_point"]
        assert row["modes"] == "parser|forward|reverse"
        assert "no-derivative-support-claim" in row["oracle"]
        assert row["tapenade_result"].startswith("pass-")
        for engines in case["modes"].values():
            assert engines["tapenade"]["status"] == "pass"

    by_id = {case["id"]: case for case in result["cases"]}
    for case_id in ("set03-cm07", "set03-cm09"):
        modes = by_id[case_id]["modes"]
        assert all(modes[mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
        assert "pointer association storage identity" in modes["parser"]["fortad"]["stderr"]

    for case_id in ("set04-v006", "set11-v006"):
        modes = by_id[case_id]["modes"]
        assert modes["parser"]["fortad"]["status"] == "pass"
        assert modes["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["status"] == "refused"
        assert "Invalid character in name" in modes["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["stderr"]
        assert modes["forward"]["fortad"]["status"] == "refused"
        assert modes["reverse"]["fortad"]["status"] == "refused"
        assert "active derived object 'a' must name a real component" in modes["forward"]["fortad"]["stderr"]

    for relative in (manifest["queue_file"], manifest["batch_file"]):
        rows = [json.loads(line) for line in (ROOT / relative).read_text(encoding="utf-8").splitlines() if line]
        assert not selected_paths.intersection(row["path"] for row in rows)


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"cm07-pointer-storage", "cm09-pointer-storage", "v006-derived-generic"}
    assert all(value["status"] == "pass" for value in values.values())
    assert values["v006-derived-generic"]["derivative"]["status"] == "verified"
    assert values["cm07-pointer-storage"]["refusal"]["status"] == "expected"
    assert values["cm09-pointer-storage"]["refusal"]["status"] == "expected"


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
