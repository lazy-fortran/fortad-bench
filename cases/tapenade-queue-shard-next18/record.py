#!/usr/bin/env python3
"""Canonicalize next18 exact-source Tapenade/FortAD probe records."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UPSTREAM = ROOT / "upstream" / "tapenade"
CASE = Path(__file__).resolve().parent
FIXED = {".f", ".for", ".ftn", ".f77"}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], *, cwd: Path | None = None) -> dict[str, object]:
    process = subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)
    return {"status": "pass" if process.returncode == 0 else "refused", "returncode": process.returncode, "command": command, "stderr": process.stderr[-4000:], "stdout": process.stdout[-4000:]}


def source_check(source: str) -> dict[str, dict[str, object]]:
    path = UPSTREAM / source
    case = path.parent
    form = "-ffixed-line-length-none" if path.suffix.lower() in FIXED else "-ffree-line-length-none"
    checks = {}
    with tempfile.TemporaryDirectory(prefix="fortad-next18-source-", dir="/var/tmp") as module_dir:
        for label, standard in (("strict", "-std=f2018"), ("legacy", "-std=legacy")):
            checks[label] = run(["gfortran", "-fsyntax-only", standard, form, "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", "-I", str(case), f"-J{module_dir}", path.name], cwd=case)
    return checks


def generated_check(path: Path) -> dict[str, object]:
    form = "-ffixed-line-length-none" if path.suffix.lower() in FIXED else "-ffree-line-length-none"
    with tempfile.TemporaryDirectory(prefix="fortad-next18-generated-", dir="/var/tmp") as module_dir:
        return run(["gfortran", "-fsyntax-only", "-std=f2018", form, "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", f"-J{module_dir}", str(path)])


def normalize_probe(value: dict[str, object], result_dir: str, mode: str, tool: str) -> dict[str, object]:
    result = {key: value.get(key) for key in ("status", "returncode", "seconds", "command", "generated", "stderr", "stdout")}
    result["generated_syntax"] = {}
    output = Path(result_dir) / mode / tool
    for generated in value.get("generated", []):
        if Path(str(generated)).suffix.lower() in {".f", ".f90", ".f95", ".f03", ".f08"}:
            result["generated_syntax"][generated] = generated_check(output / str(generated))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, default=CASE / "result.json")
    args = parser.parse_args()
    manifest = tomllib.loads((CASE / "manifest.toml").read_text())
    raw = [json.loads(path.read_text()) for path in args.raw]
    raw_by_path = {row["case_path"]: row for row in raw}
    baseline_ledger_text = subprocess.run(["git", "show", "HEAD:docs/corpora/tapenade-status.csv"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    baseline = {(row["component"], row["path"]): row for row in csv.DictReader(baseline_ledger_text.splitlines())}
    cases = []
    for selected in manifest["case"]:
        raw_row = raw_by_path[selected["queue_path"]]
        key = (selected["component"], selected["queue_path"])
        if baseline[key]["status"] != "untriaged":
            raise SystemExit(f"selection was not untriaged at branch base: {key}")
        if raw_row["upstream_revision"] != manifest["upstream_revision"]:
            raise SystemExit(f"upstream revision mismatch: {key}")
        oracle = subprocess.run(["python3", str(CASE / "oracle.py"), "--case", selected["oracle_case"]], capture_output=True, text=True, check=False)
        if oracle.returncode:
            raise SystemExit(f"oracle failed: {key}: {oracle.stderr}")
        modes = {mode: {tool: normalize_probe(value, raw_row["result_dir"], mode, tool) for tool, value in probes.items()} for mode, probes in raw_row["probes"].items()}
        cases.append({"id": selected["id"], "component": selected["component"], "queue_path": selected["queue_path"], "queue_rank": selected["queue_rank"], "queue_category": selected["queue_category"], "compiler_status": "pending-batch-join"})
        cases[-1].update({"source": selected["source"], "references": selected["references"], "entry_point": selected["entry_point"], "classification": selected["classification"], "closure": selected["closure"], "oracle_case": selected["oracle_case"], "upstream_revision": raw_row["upstream_revision"], "fortad_revision": raw_row["fortad_revision"], "dependency_risk": raw_row["dependency_risk"], "dependency_hints": raw_row["dependency_hints"], "probe_status": raw_row["status"], "source_reference_sha256": {source: sha256(UPSTREAM / source) for source in [selected["source"], *selected["references"]]}, "exact_source_checks": {source: source_check(source) for source in [selected["source"], *selected["references"]]}, "modes": modes, "independent_oracle": json.loads(oracle.stdout)[selected["oracle_case"]]})
    batch_text = subprocess.run(["git", "show", "HEAD:docs/corpora/tapenade-fortran-batch.jsonl"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    batch_by_key = {(row["component"], row["path"]): row for row in map(json.loads, batch_text.splitlines())}
    for row in cases:
        evidence = batch_by_key[(row["component"], row["queue_path"])]
        row["compiler_status"] = evidence["candidate_status"]
        row["compiler_files"] = evidence["compiler_files"]
        row["compiler_missing_source_files"] = evidence["compiler_missing_source_files"]
        row["compiler_extra_source_files"] = evidence["compiler_extra_source_files"]
    result = {"schema_version": 1, "shard_id": manifest["shard_id"], "queue_file": manifest["queue_file"], "batch_file": manifest["batch_file"], "selection_queue_sha256": manifest["selection_queue_sha256"], "selection_batch_sha256": manifest["selection_batch_sha256"], "current_queue_sha256": sha256(ROOT / manifest["queue_file"]), "current_batch_sha256": sha256(ROOT / manifest["batch_file"]), "upstream_revision": manifest["upstream_revision"], "fortad_revision": manifest["fortad_revision"], "jobs": 4, "cases": cases}
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
