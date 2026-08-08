"""Independent contract and oracle checks for the committed queue shard."""

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
        ledger = {
            (row["component"], row["path"]): row
            for row in csv.DictReader(stream)
        }
    assert result["shard_id"] == manifest["shard_id"]
    assert result["upstream_revision"] == manifest["upstream_revision"]
    assert result["fortad_revision"] == manifest["fortad_revision"]
    assert result["selection_queue_sha256"] == result["queue_sha256"]
    assert result["selection_batch_sha256"] == result["batch_sha256"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4
    assert {case["id"] for case in result["cases"]} == {
        "set05-v196", "set05-v202", "set06-v220", "set06-v232"
    }
    for case in result["cases"]:
        assert case["dependency_risk"] is False
        assert case["dependency_hints"] == []
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
        assert case["compiler_extra_source_files"] == []
        assert set(case["modes"]) == {"parser", "forward", "reverse"}
        assert case["independent_oracle"]["status"] == "pass"
        assert case["classification"].startswith("unsupported-")
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == case["classification"]
        assert row["entry_point"] == case["entry_point"]
        assert row["modes"] == "parser|forward|reverse"
        assert "no-derivative-support-claim" in row["oracle"]
        assert row["tapenade_result"].startswith("pass-")
        assert "refusal" in row["fortad_result"] or "refused" in row["fortad_result"]

    v196 = next(case for case in result["cases"] if case["id"] == "set05-v196")
    assert v196["modes"]["parser"]["fortad"]["status"] == "pass"
    assert "no derivative rule for 'int'" in v196["modes"]["forward"]["fortad"]["stderr"]

    v202 = next(case for case in result["cases"] if case["id"] == "set05-v202")
    assert all(
        mode["fortad"]["status"] == "refused"
        for mode in v202["modes"].values()
    )
    assert "Unclassifiable statement" in v202["modes"]["parser"]["fortad"]["stderr"]

    v220 = next(case for case in result["cases"] if case["id"] == "set06-v220")
    assert "active derived object" in v220["modes"]["forward"]["fortad"]["stderr"]
    assert v220["modes"]["parser"]["fortad"]["status"] == "pass"

    v232 = next(case for case in result["cases"] if case["id"] == "set06-v232")
    assert all(mode["fortad"]["status"] == "pass" for mode in v232["modes"].values())
    assert any(
        check["status"] == "refused"
        for mode in v232["modes"].values()
        for check in mode["fortad"].get("generated_syntax", {}).values()
    )


def test_independent_oracle() -> None:
    process = subprocess.run(
        ["python3", str(CASE / "oracle.py")],
        capture_output=True,
        text=True,
        check=False,
    )
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert {"factorial", "twice_real", "addvector", "constant-result"} == set(values)
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
