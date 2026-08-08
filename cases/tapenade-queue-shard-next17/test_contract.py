"""Contract and independent-oracle checks for next17."""

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
    expected = {
        "set01-B05": "unsupported-fortad-invalid-generated-interface",
        "set01-bd07": "unsupported-fortad-active-io",
        "set01-ht01": "unsupported-fortad-character-section",
        "set01-lh043": "unsupported-fortad-legacy-labeled-do",
    }
    assert result["shard_id"] == manifest["shard_id"]
    assert result["selection_queue_sha256"] == manifest["selection_queue_sha256"]
    assert result["selection_batch_sha256"] == manifest["selection_batch_sha256"]
    assert result["current_queue_sha256"] == sha256(ROOT / manifest["queue_file"])
    assert result["current_batch_sha256"] == sha256(ROOT / manifest["batch_file"])
    assert len(result["cases"]) == 4
    prior = set()
    for path in (ROOT / "cases").glob("tapenade-queue-shard-*/manifest.toml"):
        if path != CASE / "manifest.toml":
            prior.update(
                (case.get("component", "non-regressions"), case["queue_path"])
                for case in tomllib.loads(path.read_text()).get("case", [])
            )
    observed = {(case["component"], case["queue_path"]) for case in result["cases"]}
    assert observed.isdisjoint(prior)
    assert len(observed) == 4
    for case in result["cases"]:
        assert case["classification"] == expected[case["id"]]
        assert ledger[(case["component"], case["queue_path"])] ["status"] == case["classification"]
        assert case["independent_oracle"]["status"] == "pass"
        for source in [case["source"], *case["references"]]:
            assert case["source_reference_sha256"][source] == sha256(ROOT / "upstream/tapenade" / source)
            expected_checks = {
                "nonRegressions/set01/B05/program_b.f": ("refused", "pass"),
                "nonRegressions/set01/lh043/program_d.f": ("refused", "pass"),
            }.get(source, ("pass", "pass"))
            assert (
                case["exact_source_checks"][source]["strict"]["status"],
                case["exact_source_checks"][source]["legacy"]["status"],
            ) == expected_checks
        for mode in ("parser", "forward", "reverse"):
            assert case["modes"][mode]["tapenade"]["status"] == "pass"
    by_id = {case["id"]: case for case in result["cases"]}
    assert by_id["set01-B05"]["modes"]["parser"]["fortad"]["status"] == "pass"
    assert by_id["set01-B05"]["modes"]["forward"]["fortad"]["status"] == "pass"
    assert by_id["set01-B05"]["modes"]["parser"]["fortad"]["generated_syntax"]["probe_p.f90"]["status"] == "refused"
    assert by_id["set01-B05"]["modes"]["forward"]["fortad"]["generated_syntax"]["probe_d.f90"]["status"] == "refused"
    assert "could not infer Tapenade dependent" in by_id["set01-B05"]["modes"]["reverse"]["fortad"]["stderr"]
    for case_id in ("set01-bd07", "set01-ht01", "set01-lh043"):
        case = by_id[case_id]
        assert all(case["modes"][mode]["fortad"]["status"] == "refused" for mode in ("parser", "forward", "reverse"))
    assert "active-I/O" in by_id["set01-bd07"]["closure"]
    assert "CHARACTER" in by_id["set01-ht01"]["closure"]
    assert "labeled" in by_id["set01-lh043"]["closure"]


def test_independent_oracle() -> None:
    process = subprocess.run(["python3", str(CASE / "oracle.py")], capture_output=True, text=True)
    assert process.returncode == 0, process.stderr
    values = json.loads(process.stdout)
    assert set(values) == {
        "B05-flux-interface-storage", "bd07-array-read-boundary",
        "ht01-character-substring", "lh043-labeled-do-common",
    }
    assert all(value["status"] == "pass" for value in values.values())


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
