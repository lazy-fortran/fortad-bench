"""Contract and independent-oracle checks for next44."""

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
        "set06-v315": (22, "final=1; dimension=5", "unsupported-fortad-mpi-call-rule", "msg1"),
        "set03-lh087": (15, "dimension=5", "runnable-ported", "cross_prod"),
        "set11-html01": (15, "bind(c)=2; iso_c_binding=1", "unsupported-fortad-common-block", "barf"),
        "set03-bd09": (14, "pointer=1", "invalid-upstream-pointer-allocation-sequence", "head"),
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
        assert case["compiler_missing_source_files"] == [] or all(item.endswith("mpif.h") for item in case["compiler_missing_source_files"])
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
            assert case["modes"][mode]["fortad"]["status"] == ("pass" if case["id"] == "set03-lh087" or (case["id"] == "set06-v315" and mode == "parser") else "refused")
            if case["modes"][mode]["fortad"]["status"] == "refused":
                assert case["modes"][mode]["fortad"]["generated"] == []
            elif case["id"] == "set03-lh087":
                assert all(value["status"] == "pass" for value in case["modes"][mode]["fortad"]["generated_syntax"].values())
    v315 = next(case for case in result["cases"] if case["id"] == "set06-v315")
    assert "no derivative rule for the call to 'MPI_ISEND'" in v315["modes"]["forward"]["fortad"]["stderr"]
    assert "could not infer Tapenade dependent" in v315["modes"]["reverse"]["fortad"]["stderr"]
    lh087 = next(case for case in result["cases"] if case["id"] == "set03-lh087")
    assert all(lh087["modes"][mode]["fortad"]["status"] == "pass" for mode in ("parser", "forward", "reverse"))
    html01 = next(case for case in result["cases"] if case["id"] == "set11-html01")
    assert all("parse failed" in html01["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))
    bd09 = next(case for case in result["cases"] if case["id"] == "set03-bd09")
    assert all("pointer association storage identity" in bd09["modes"][mode]["fortad"]["stderr"] for mode in ("parser", "forward", "reverse"))


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
