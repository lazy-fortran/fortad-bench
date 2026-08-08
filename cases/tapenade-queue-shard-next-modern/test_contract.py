"""Contract and independent-oracle checks for the modern-feature shard."""

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
    assert {case["id"] for case in result["cases"]} == {"set04-ptr08", "set04-ptr07", "set06-v243", "set05-v180"}
    scores = {case["id"]: (case["selection_score"], case["selection_features"]) for case in result["cases"]}
    assert scores == {
        "set04-ptr08": (197, "pointer=7; associate=4; type(=5; recursive=1; dimension=1"),
        "set04-ptr07": (195, "pointer=7; associate=3; type ::=1; type(=5; recursive=1; dimension=1"),
        "set06-v243": (192, "pointer=8; associate=4; type(=1; dimension=8"),
        "set05-v180": (149, "procedure=1; interface=2; optional=14; dimension=25"),
    }
    for case in result["cases"]:
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert set(case["modes"]) == {"parser", "forward", "reverse"}
        assert case["independent_oracle"]["status"] == "pass"
        assert case["classification"] == "expected-refusal" or case["classification"].startswith("unsupported-")
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == case["classification"]
        assert row["entry_point"] == case["entry_point"]
        assert row["modes"] == "parser|forward|reverse"
        assert "no-derivative-support-claim" in row["oracle"]
        assert row["tapenade_result"].startswith("pass-")
        assert "refusal" in row["fortad_result"] or "refused" in row["fortad_result"]
    for case_id in ("set04-ptr07", "set04-ptr08"):
        case = next(case for case in result["cases"] if case["id"] == case_id)
        assert all(mode["fortad"]["status"] == "refused" for mode in case["modes"].values())
        assert "unsupported statement at line 1" in case["modes"]["parser"]["fortad"]["stderr"]
    v243 = next(case for case in result["cases"] if case["id"] == "set06-v243")
    assert all(mode["fortad"]["status"] == "refused" for mode in v243["modes"].values())
    assert "non-allocatable target" in v243["modes"]["parser"]["fortad"]["stderr"]
    v180 = next(case for case in result["cases"] if case["id"] == "set05-v180")
    assert v180["modes"]["parser"]["fortad"]["status"] == "pass"
    assert v180["modes"]["forward"]["fortad"]["status"] == "pass"
    assert v180["modes"]["reverse"]["fortad"]["status"] == "refused"
    assert "could not infer Tapenade dependent" in v180["modes"]["reverse"]["fortad"]["stderr"]
    assert any(
        check["status"] == "refused"
        for mode in ("parser", "forward")
        for check in v180["modes"][mode]["fortad"]["generated_syntax"].values()
    )


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"ptr07-remove", "ptr08-remove", "v243-collect-garbage", "v180-fliogstc"}
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
