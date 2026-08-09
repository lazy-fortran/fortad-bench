"""Contract and independent-oracle checks for next43."""

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
        "set04-v018": (16, "type(=2", "unsupported-fortad-active-io", "test"),
        "set04-v043": (16, "type(=2", "unsupported-fortad-invalid-generated-interface", "ff"),
        "set07-v496": (16, "interface=2; dimension=2", "unsupported-fortad-invalid-generated-interface", "top"),
        "set10-lh238": (16, "type(=2", "unsupported-fortad-derived-type-component", "foo"),
    }
    assert result["shard_id"] == manifest["shard_id"]
    assert result["upstream_revision"] == manifest["upstream_revision"]
    assert result["fortad_revision"] == manifest["fortad_revision"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4
    assert len({(case["component"], case["queue_path"]) for case in result["cases"]}) == 4
    for case in result["cases"]:
        score, features, classification, entry = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"], case["entry_point"]) == (score, features, classification, entry)
        assert case["selection"] == "modern-feature-score-then-queue-order"
        assert case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == []
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
            if case["id"] == "set07-v496" and mode in ("forward", "reverse"):
                generated_name = {"forward": "probe_d.f90", "reverse": "probe_b.f90"}[mode]
                assert case["modes"][mode]["tapenade"]["generated_syntax"][generated_name]["status"] == "refused"
                assert "Cannot open module file" in case["modes"][mode]["tapenade"]["generated_syntax"][generated_name]["stderr"]
            else:
                assert all(item["status"] == "pass" for item in case["modes"][mode]["tapenade"]["generated_syntax"].values())
            if case["id"] == "set04-v043" and mode == "parser":
                assert case["modes"][mode]["fortad"]["status"] == "pass"
                assert case["modes"][mode]["fortad"]["generated"] == ["probe_p.f90"]
            else:
                assert case["modes"][mode]["fortad"]["status"] == "refused"
                assert case["modes"][mode]["fortad"]["generated"] == []
    v018 = next(case for case in result["cases"] if case["id"] == "set04-v018")
    assert all("unsupported statement at line 18" in v018["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    v043 = next(case for case in result["cases"] if case["id"] == "set04-v043")
    assert v043["classification"] == "unsupported-fortad-invalid-generated-interface"
    assert v043["modes"]["parser"]["fortad"]["status"] == "pass"
    assert v043["modes"]["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["status"] == "refused"
    assert "Invalid character in name" in v043["modes"]["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["stderr"]
    assert all("active derived object 't' must name a real component" in v043["modes"][mode]["fortad"]["stderr"] for mode in ("forward", "reverse"))
    v496 = next(case for case in result["cases"] if case["id"] == "set07-v496")
    assert all("unsupported statement at line 12" in v496["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    lh238 = next(case for case in result["cases"] if case["id"] == "set10-lh238")
    assert all("unsupported statement at line 1" in lh238["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))


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
