#!/usr/bin/env python3
"""Canonicalize next40's exact Tapenade/FortAD probe records."""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import subprocess
import tomllib
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[1]


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _normalize(value: str | None, result_dir: str) -> str:
    value = (value or "").replace(result_dir, "$RESULT_DIR")
    return value if len(value) <= 1200 else "..." + value[-1200:]


def _command(value: list[str] | None, result_dir: str) -> list[str] | None:
    return [item.replace(result_dir, "$RESULT_DIR") for item in value] if value else None


def _syntax_check(path: Path, result_dir: str) -> dict[str, object]:
    process = subprocess.run(
        ["gfortran", "-fsyntax-only", "-std=f2018", "-ffree-line-length-none", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    return {
        "status": "pass" if process.returncode == 0 else "refused",
        "returncode": process.returncode,
        "stderr": _normalize(process.stderr, result_dir),
    }


def _engine_result(value: dict, result_dir: str, mode: str, engine: str) -> dict[str, object]:
    result: dict[str, object] = {
        "status": value.get("status"),
        "returncode": value.get("returncode"),
        "command": _command(value.get("command"), result_dir),
        "generated": sorted(value.get("generated", [])),
        "stdout": _normalize(value.get("stdout"), result_dir),
        "stderr": _normalize(value.get("stderr"), result_dir),
        "generated_syntax": {},
    }
    output = Path(result_dir) / mode / engine
    syntax = result["generated_syntax"]
    assert isinstance(syntax, dict)
    for generated in result["generated"]:
        if generated.endswith(".f90"):
            syntax[generated] = _syntax_check(output / generated, result_dir)
    return result


def _check_branch_base(manifest: dict) -> None:
    for relative, expected in (
        (manifest["queue_file"], manifest["selection_queue_sha256"]),
        (manifest["batch_file"], manifest["selection_batch_sha256"]),
    ):
        text = subprocess.run(
            ["git", "show", f"HEAD:{relative}"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        if _sha256_text(text) != expected:
            raise SystemExit(f"branch-base {relative} does not match selection hash")
    baseline = subprocess.run(
        ["git", "show", "HEAD:docs/corpora/tapenade-status.csv"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    rows = {(row["component"], row["path"]): row for row in csv.DictReader(baseline.splitlines())}
    for selected in manifest["case"]:
        key = (selected["component"], selected["queue_path"])
        if rows[key]["status"] != "untriaged":
            raise SystemExit(f"selected row was not untriaged at branch base: {key}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, default=CASE / "result.json")
    args = parser.parse_args()
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    _check_branch_base(manifest)
    raw = [json.loads(path.read_text(encoding="utf-8")) for path in args.raw]
    raw_by_key = {(row["case_path"], row["entry_point"]): row for row in raw}
    baseline_text = subprocess.run(
        ["git", "show", f"HEAD:{manifest['batch_file']}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if _sha256_text(baseline_text) != manifest["selection_batch_sha256"]:
        raise SystemExit("branch-base batch does not match selection_batch_sha256")
    baseline = {
        (row["component"], row["path"]): row
        for row in (json.loads(line) for line in baseline_text.splitlines() if line.strip())
    }
    oracle_path = CASE / "oracle.py"
    cases = []
    for selected in manifest["case"]:
        raw_row = raw_by_key[(selected["queue_path"], selected["entry_point"])]
        if raw_row["upstream_revision"] != manifest["upstream_revision"]:
            raise SystemExit(f"upstream revision mismatch for {selected['id']}")
        if raw_row["fortad_revision"] != manifest["fortad_revision"]:
            raise SystemExit(f"FortAD revision mismatch for {selected['id']}")
        batch = baseline[(selected["component"], selected["queue_path"])]
        if batch["candidate_status"] != selected["compiler_status"]:
            raise SystemExit(f"compiler evidence changed for {selected['id']}")
        modes = {
            mode: {
                engine: _engine_result(value, raw_row["result_dir"], mode, engine)
                for engine, value in probes.items()
            }
            for mode, probes in raw_row["probes"].items()
        }
        oracle = subprocess.run(
            ["python3", str(oracle_path), "--case", selected["oracle_case"]],
            capture_output=True,
            text=True,
            check=False,
        )
        if oracle.returncode != 0:
            raise SystemExit(f"oracle failed for {selected['id']}: {oracle.stderr}")
        oracle_value = json.loads(oracle.stdout)[selected["oracle_case"]]
        source_paths = [selected["source"], *selected["references"]]
        cases.append({
            "id": selected["id"],
            "component": selected["component"],
            "queue_path": selected["queue_path"],
            "queue_rank": selected["queue_rank"],
            "queue_category": selected["queue_category"],
            "selection_score": selected["selection_score"],
            "selection_features": selected["selection_features"],
            "compiler_status": batch["candidate_status"],
            "compiler_files": batch["compiler_files"],
            "compiler_missing_source_files": batch["compiler_missing_source_files"],
            "compiler_extra_source_files": batch["compiler_extra_source_files"],
            "source": selected["source"],
            "references": selected["references"],
            "source_reference_sha256": {path: _sha256(ROOT / "upstream/tapenade" / path) for path in source_paths},
            "entry_point": selected["entry_point"],
            "selection": "modern-feature-score-then-queue-order",
            "classification": selected["classification"],
            "closure": selected["closure"],
            "upstream_revision": raw_row["upstream_revision"],
            "fortad_revision": raw_row["fortad_revision"],
            "dependency_risk": raw_row["dependency_risk"],
            "dependency_hints": raw_row["dependency_hints"],
            "probe_status": raw_row["status"],
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
        "current_queue_sha256": _sha256(ROOT / manifest["queue_file"]),
        "current_batch_sha256": _sha256(ROOT / manifest["batch_file"]),
        "upstream_revision": manifest["upstream_revision"],
        "fortad_revision": manifest["fortad_revision"],
        "jobs": 4,
        "cases": cases,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
