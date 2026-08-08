"""Contract and independent-oracle checks for the next6 shard."""

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

    expected = {
        "set11-lh011": (117, "allocatable=2; pointer=2; type(=5; dimension=7", "unsupported-fortad-global-mutable-state"),
        "set04-lh156": (108, "interface=6; dimension=26", "expected-refusal"),
        "set07-v521": (105, "pointer=5; interface=4; dimension=5", "unsupported-fortad-pointer-alias-lifetime"),
        "set11-vpf17": (102, "type(=7; procedure=2; interface=6", "unsupported-fortad-invalid-generated-interface"),
    }
    assert {case["id"] for case in result["cases"]} == set(expected)

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
        for mode, engines in case["modes"].items():
            assert engines["tapenade"]["status"] == "pass"

    by_id = {case["id"]: case for case in result["cases"]}
    assert all(by_id["set11-lh011"]["modes"][mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
    assert "module-level allocatable mutable state" in by_id["set11-lh011"]["modes"]["parser"]["fortad"]["stderr"]

    lh156 = by_id["set04-lh156"]["modes"]
    assert lh156["parser"]["fortad"]["status"] == "pass"
    assert lh156["forward"]["fortad"]["status"] == "pass"
    assert lh156["reverse"]["fortad"]["status"] == "refused"
    assert "could not infer Tapenade dependent" in lh156["reverse"]["fortad"]["stderr"]

    v521 = by_id["set07-v521"]["modes"]
    assert all(v521[mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
    assert "pointer association storage identity" in v521["parser"]["fortad"]["stderr"]

    vpf17 = by_id["set11-vpf17"]["modes"]
    assert all(vpf17[mode]["fortad"]["status"] == "pass" for mode in ("parser", "forward", "reverse"))
    assert vpf17["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["status"] == "pass"
    assert vpf17["forward"]["fortad"]["generated_syntax"]["probe_d.f90"]["status"] == "pass"
    assert vpf17["reverse"]["fortad"]["generated_syntax"]["probe_b.f90"]["status"] == "refused"


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {"lh011-module-state", "lh156-no-dependent", "v521-pointer-global", "vpf17-nested-derived"}
    assert all(value["status"] == "pass" for value in values.values())
    assert values["vpf17-nested-derived"]["derivative"]["status"] == "verified"


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
