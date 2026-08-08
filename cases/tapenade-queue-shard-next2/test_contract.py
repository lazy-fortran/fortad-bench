"""Contract and independent-oracle checks for the next2 shard."""
from __future__ import annotations
import csv, hashlib, json, subprocess, tomllib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
CASE = Path(__file__).resolve().parent
def sha256(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def test_contract():
    manifest = tomllib.loads((CASE / "manifest.toml").read_text())
    result = json.loads((CASE / "result.json").read_text())
    with (ROOT / "docs/corpora/tapenade-status.csv").open(newline="") as stream: ledger = {(row["component"], row["path"]): row for row in csv.DictReader(stream)}
    expected = {"set11-vpf19": (154, "type(=72; procedure=32; interface=50", "unsupported-fortad-derived-type-component"), "set07-v479": (145, "allocatable=14; pointer=56; type(=72; dimension=3", "unsupported-fortad-global-mutable-state"), "set04-lh111": (130, "pointer=7; type(=1; dimension=8", "unsupported-fortad-pointer-alias-lifetime"), "set07-v520": (122, "allocatable=56; type(=48; dimension=18", "unsupported-fortad-allocatable-derived-component")}
    assert result["shard_id"] == manifest["shard_id"] and result["upstream_revision"] == manifest["upstream_revision"] and result["fortad_revision"] == manifest["fortad_revision"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"] and result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == manifest["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == manifest["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert {case["id"] for case in result["cases"]} == set(expected)
    for case in result["cases"]:
        score, features, classification = expected[case["id"]]
        assert (case["selection_score"], case["selection_features"], case["classification"]) == (score, features, classification)
        assert case["selection"] == "modern-feature-score-then-queue-order-real-source-entry" and case["compiler_status"] == "compiler-clean"
        assert case["compiler_missing_source_files"] == [] and case["compiler_extra_source_files"] == [] and case["dependency_risk"] is False and case["dependency_hints"] == []
        assert all(value["status"] == "pass" for value in case["exact_source_checks"].values()) and set(case["modes"]) == {"parser", "forward", "reverse"} and case["independent_oracle"]["status"] == "pass"
        row = ledger[(case["component"], case["queue_path"])]
        assert row["status"] == classification and row["entry_point"] == case["entry_point"] and row["modes"] == "parser|forward|reverse" and "no-derivative-support-claim" in row["oracle"] and row["tapenade_result"].startswith("pass-") and "refused" in row["fortad_result"]
        for mode in case["modes"].values():
            assert mode["tapenade"]["status"] == "pass"
            for generated, syntax in mode["tapenade"]["generated_syntax"].items():
                if case["id"] == "set11-vpf19" and mode is case["modes"].get("forward") and generated == "probe_d.f90":
                    assert syntax["status"] == "refused" and "generic" in syntax["stderr"]
                else:
                    assert syntax["status"] == "pass"
        if case["id"] == "set11-vpf19":
            assert case["modes"]["parser"]["fortad"]["status"] == "pass" and case["modes"]["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["status"] == "refused"
            assert all(case["modes"][mode]["fortad"]["status"] == "refused" for mode in ("forward", "reverse"))
        else: assert all(case["modes"][mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
    assert "module-level allocatable mutable state" in next(case for case in result["cases"] if case["id"] == "set07-v479")["modes"]["parser"]["fortad"]["stderr"]
    assert "pointer association storage identity" in next(case for case in result["cases"] if case["id"] == "set04-lh111")["modes"]["parser"]["fortad"]["stderr"]

def test_independent_oracle():
    p = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True, check=False)
    assert p.returncode == 0, p.stderr
    values = json.loads(p.stdout)
    assert set(values) == {"vpf19-nested-difference", "v479-module-state", "lh111-pointer-field", "v520-force-calculation"} and all(value["status"] == "pass" for value in values.values())

if __name__ == "__main__": test_contract(); test_independent_oracle()
