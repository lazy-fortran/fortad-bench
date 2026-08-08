#!/usr/bin/env python3
"""Canonicalize one existing probe run into deterministic committed evidence."""

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


def tail(value: str | None) -> str:
    value = value or ""
    return value if len(value) <= 1200 else "..." + value[-1200:]


def normalize_text(value: str | None, result_dir: str) -> str:
    return tail((value or "").replace(result_dir, "$RESULT_DIR"))


def normalize_command(command: list[str] | None, result_dir: str) -> list[str] | None:
    if command is None:
        return None
    return [item.replace(result_dir, "$RESULT_DIR") for item in command]


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
        "stderr": normalize_text(process.stderr, result_dir),
    }


def engine_result(value: dict, result_dir: str) -> dict:
    result = {
        "status": value.get("status"),
        "returncode": value.get("returncode"),
        "command": normalize_command(value.get("command"), result_dir),
        "generated": sorted(value.get("generated", [])),
        "stdout": normalize_text(value.get("stdout"), result_dir),
        "stderr": normalize_text(value.get("stderr"), result_dir),
    }
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=CASE / "result.json")
    args = parser.parse_args()
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    raw = [json.loads(line) for line in args.raw.read_text(encoding="utf-8").splitlines() if line.strip()]
    by_key = {(row["candidate_key"], row["entry_point"]): row for row in raw}
    existing_cases = {}
    evidence_path = CASE / "result.json"
    if evidence_path.is_file():
        existing = json.loads(evidence_path.read_text(encoding="utf-8"))
        existing_cases = {row["id"]: row for row in existing.get("cases", [])}
    batch_rows = {
        (row["component"], row["path"]): row
        for row in (
            json.loads(line)
            for line in (ROOT / manifest["batch_file"]).read_text(encoding="utf-8").splitlines()
            if line.strip()
        )
    }
    cases = []
    for selected in manifest["case"]:
        key = f"{selected['component']}:{selected['queue_path']}"
        record = by_key[(key, selected["entry_point"])]
        batch = batch_rows.get((selected["component"], selected["queue_path"]))
        if batch is None:
            prior = existing_cases.get(selected["id"])
            if prior is None:
                raise SystemExit(
                    f"closed compiler row {selected['id']} has no committed evidence fallback"
                )
            compiler_status = prior["compiler_status"]
            compiler_files = prior["compiler_files"]
            compiler_missing = prior["compiler_missing_source_files"]
            compiler_extra = prior["compiler_extra_source_files"]
        else:
            compiler_status = batch["candidate_status"]
            compiler_files = batch["compiler_files"]
            compiler_missing = batch["compiler_missing_source_files"]
            compiler_extra = batch["compiler_extra_source_files"]
        if compiler_status != selected["compiler_status"]:
            raise SystemExit(
                f"compiler status changed for {selected['id']}: "
                f"{compiler_status} != {selected['compiler_status']}"
            )
        source_paths = [selected["source"], *selected["references"]]
        hashes = {path: sha256(UPSTREAM / path) for path in source_paths}
        modes = {}
        for mode, probes in record["probes"].items():
            modes[mode] = {}
            for engine in ("tapenade", "fortad"):
                value = probes[engine]
                canonical = engine_result(value, record["result_dir"])
                if engine == "fortad":
                    generated_checks = {}
                    output_dir = Path(record["result_dir"]) / mode / "fortad"
                    for generated in canonical["generated"]:
                        if generated.endswith(".f90"):
                            generated_checks[generated] = syntax_check(
                                output_dir / generated, record["result_dir"]
                            )
                    canonical["generated_syntax"] = generated_checks
                modes[mode][engine] = canonical
        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py"), "--case", selected["oracle_case"]],
            capture_output=True,
            text=True,
            check=False,
        )
        if oracle.returncode != 0:
            raise SystemExit(f"oracle failed for {selected['id']}: {oracle.stderr}")
        oracle_values = json.loads(oracle.stdout)
        oracle_value = oracle_values[selected["oracle_case"]]
        cases.append({
            "id": selected["id"],
            "component": selected["component"],
            "queue_path": selected["queue_path"],
            "queue_rank": selected["queue_rank"],
            "queue_category": selected["queue_category"],
            "compiler_status": compiler_status,
            "compiler_files": compiler_files,
            "compiler_missing_source_files": compiler_missing,
            "compiler_extra_source_files": compiler_extra,
            "source": selected["source"],
            "references": selected["references"],
            "source_reference_sha256": hashes,
            "entry_point": selected["entry_point"],
            "selection": "static-unambiguous",
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
    selection_queue_sha256 = manifest.get("selection_queue_sha256", sha256(ROOT / manifest["queue_file"]))
    selection_batch_sha256 = manifest.get("selection_batch_sha256", sha256(ROOT / manifest["batch_file"]))
    result = {
        "schema_version": 1,
        "shard_id": manifest["shard_id"],
        "queue_file": manifest["queue_file"],
        "queue_sha256": selection_queue_sha256,
        "batch_file": manifest["batch_file"],
        "batch_sha256": selection_batch_sha256,
        "selection_queue_sha256": selection_queue_sha256,
        "selection_batch_sha256": selection_batch_sha256,
        "current_queue_sha256": sha256(ROOT / manifest["queue_file"]),
        "current_batch_sha256": sha256(ROOT / manifest["batch_file"]),
        "upstream_revision": manifest["upstream_revision"],
        "fortad_revision": manifest["fortad_revision"],
        "jobs": 4,
        "cases": cases,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
