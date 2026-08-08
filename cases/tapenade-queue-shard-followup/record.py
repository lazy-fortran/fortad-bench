#!/usr/bin/env python3
"""Canonicalize the four exact single-case probe records for this shard."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UPSTREAM = ROOT / "upstream" / "tapenade"
CASE = Path(__file__).resolve().parent


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalize(value: str | None, result_dir: str) -> str:
    value = value or ""
    value = value.replace(result_dir, "$RESULT_DIR")
    return value if len(value) <= 1200 else "..." + value[-1200:]


def engine_result(value: dict, result_dir: str) -> dict:
    command = value.get("command")
    return {
        "status": value.get("status"),
        "returncode": value.get("returncode"),
        "command": [item.replace(result_dir, "$RESULT_DIR") for item in command] if command else None,
        "generated": sorted(value.get("generated", [])),
        "stdout": normalize(value.get("stdout"), result_dir),
        "stderr": normalize(value.get("stderr"), result_dir),
    }


def syntax_check(path: Path, result_dir: str) -> dict:
    process = subprocess.run(
        ["gfortran", "-fsyntax-only", "-std=f2018", "-ffree-line-length-none", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    return {
        "status": "pass" if process.returncode == 0 else "refused",
        "returncode": process.returncode,
        "stderr": normalize(process.stderr, result_dir),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, default=CASE / "result.json")
    args = parser.parse_args()
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    raw = [json.loads(path.read_text(encoding="utf-8")) for path in args.raw]
    selected_by_path = {item["queue_path"]: item for item in manifest["case"]}
    records = {}
    for row in raw:
        selected = selected_by_path.get(row["case_path"])
        if selected is None:
            raise SystemExit(f"raw probe is not in manifest: {row['case_path']}")
        key = (f"{selected['component']}:{selected['queue_path']}", row["entry_point"])
        if key in records:
            raise SystemExit(f"duplicate probe record: {key}")
        records[key] = row
    cases = []
    batch_rows = {
        (row["component"], row["path"]): row
        for row in (
            json.loads(line)
            for line in (ROOT / manifest["batch_file"]).read_text(encoding="utf-8").splitlines()
            if line.strip()
        )
    }
    # Closed rows disappear from the regenerated current batch.  Read the
    # exact pre-closure batch from the branch base, whose hash is recorded as
    # selection_batch_sha256, so compiler evidence is not reconstructed.
    baseline = subprocess.run(
        ["git", "show", f"HEAD:{manifest['batch_file']}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if hashlib.sha256(baseline.encode()).hexdigest() != manifest["selection_batch_sha256"]:
        raise SystemExit("branch-base batch does not match selection_batch_sha256")
    for line in baseline.splitlines():
        if line.strip():
            row = json.loads(line)
            batch_rows.setdefault((row["component"], row["path"]), row)
    for selected in manifest["case"]:
        key = (f"{selected['component']}:{selected['queue_path']}", selected["entry_point"])
        record = records.get(key)
        if record is None:
            raise SystemExit(f"missing probe record: {key}")
        batch = batch_rows.get((selected["component"], selected["queue_path"]))
        if batch is None or batch["candidate_status"] != selected["compiler_status"]:
            raise SystemExit(f"compiler evidence changed for {selected['id']}")
        source_paths = [selected["source"], *selected["references"]]
        modes = {}
        for mode, probes in record["probes"].items():
            modes[mode] = {}
            for engine in ("tapenade", "fortad"):
                value = engine_result(probes[engine], record["result_dir"])
                checks = {}
                output_dir = Path(record["result_dir"]) / mode / engine
                for generated in value["generated"]:
                    if generated.endswith(".f90"):
                        checks[generated] = syntax_check(output_dir / generated, record["result_dir"])
                value["generated_syntax"] = checks
                modes[mode][engine] = value
        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py"), "--case", selected["oracle_case"]],
            capture_output=True,
            text=True,
            check=False,
        )
        if oracle.returncode != 0:
            raise SystemExit(f"oracle failed for {selected['id']}: {oracle.stderr}")
        oracle_value = json.loads(oracle.stdout)[selected["oracle_case"]]
        cases.append({
            "id": selected["id"],
            "component": selected["component"],
            "queue_path": selected["queue_path"],
            "queue_rank": selected["queue_rank"],
            "queue_category": selected["queue_category"],
            "compiler_status": batch["candidate_status"],
            "compiler_files": batch["compiler_files"],
            "compiler_missing_source_files": batch["compiler_missing_source_files"],
            "compiler_extra_source_files": batch["compiler_extra_source_files"],
            "source": selected["source"],
            "references": selected["references"],
            "source_reference_sha256": {path: sha256(UPSTREAM / path) for path in source_paths},
            "entry_point": selected["entry_point"],
            "selection": "modern-feature-score-then-queue-order",
            "classification": selected["classification"],
            "closure": selected["closure"],
            "upstream_revision": record["upstream_revision"],
            "fortad_revision": record["fortad_revision"],
            "dependency_risk": record["dependency_risk"],
            "dependency_hints": record["dependency_hints"],
            "probe_status": record["status"],
            "modes": modes,
            "independent_oracle": oracle_value,
        })
    result = {
        "schema_version": 1,
        "shard_id": manifest["shard_id"],
        "queue_file": manifest["queue_file"],
        "queue_sha256": manifest["selection_queue_sha256"],
        "batch_file": manifest["batch_file"],
        "batch_sha256": manifest["selection_batch_sha256"],
        "selection_queue_sha256": manifest["selection_queue_sha256"],
        "selection_batch_sha256": manifest["selection_batch_sha256"],
        "current_queue_sha256": sha256(ROOT / manifest["queue_file"]),
        "current_batch_sha256": sha256(ROOT / manifest["batch_file"]),
        "upstream_revision": manifest["upstream_revision"],
        "fortad_revision": manifest["fortad_revision"],
        "jobs": 4,
        "cases": cases,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
