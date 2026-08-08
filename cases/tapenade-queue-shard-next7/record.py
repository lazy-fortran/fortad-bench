#!/usr/bin/env python3
"""Canonicalize four exact next7 probe records into committed evidence."""

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
FLAGS = [
    "-fsyntax-only",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalize(value: str | None, directory: str | Path) -> str:
    value = (value or "").replace(str(directory), "$RESULT_DIR")
    return value if len(value) <= 1800 else "..." + value[-1800:]


def command(value: list[str] | None, directory: str | Path) -> list[str] | None:
    return [item.replace(str(directory), "$RESULT_DIR") for item in value] if value else None


def compiler_check(source: str) -> dict[str, dict[str, object]]:
    case = UPSTREAM / Path(source).parent
    name = Path(source).name
    checks: dict[str, dict[str, object]] = {}
    with tempfile.TemporaryDirectory(prefix="fortad-next7-", dir="/var/tmp") as module_dir:
        for label, standard in (("strict", "-std=f2018"), ("legacy", "-std=legacy")):
            process = subprocess.run(
                ["gfortran", standard, *FLAGS, f"-J{module_dir}", name],
                cwd=case,
                capture_output=True,
                text=True,
                check=False,
            )
            checks[label] = {
                "status": "pass" if process.returncode == 0 else "refused",
                "returncode": process.returncode,
                "command": ["gfortran", standard, *FLAGS, "-J$MODULE_DIR", name],
                "stderr": normalize(process.stderr, case),
            }
    return checks


def generated_check(path: Path, source: str) -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix="fortad-next7-generated-", dir="/var/tmp") as module_dir:
        base = subprocess.run(
            [
                "gfortran",
                "-c",
                "-std=f2018",
                *FLAGS[1:],
                f"-J{module_dir}",
                "-o",
                f"{module_dir}/source.o",
                str(UPSTREAM / source),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if base.returncode:
            return {
                "status": "refused",
                "returncode": base.returncode,
                "stderr": normalize(base.stderr, path.parent),
            }
        process = subprocess.run(
            [
                "gfortran",
                "-fsyntax-only",
                "-std=f2018",
                *FLAGS[1:],
                f"-I{module_dir}",
                f"-J{module_dir}",
                str(path),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        return {
            "status": "pass" if process.returncode == 0 else "refused",
            "returncode": process.returncode,
            "stderr": normalize(process.stderr, path.parent),
        }


def engine(value: dict, directory: str, mode: str, name: str, source: str) -> dict:
    result = {
        "status": value.get("status"),
        "returncode": value.get("returncode"),
        "seconds": value.get("seconds"),
        "command": command(value.get("command"), directory),
        "generated": sorted(value.get("generated", [])),
        "stdout": normalize(value.get("stdout"), directory),
        "stderr": normalize(value.get("stderr"), directory),
        "generated_syntax": {},
    }
    output = Path(directory) / mode / name
    for generated in result["generated"]:
        if generated.endswith(".f90"):
            result["generated_syntax"][generated] = generated_check(output / generated, source)
    return result


def fortad_code_is_pinned(observed: str | None, expected: str) -> bool:
    if observed == expected:
        return True
    if not observed:
        return False
    changed = subprocess.run(
        [
            "git",
            "-C",
            str(ROOT.parent.parent / "fortad"),
            "diff",
            "--name-only",
            f"{expected}..{observed}",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    return changed.returncode == 0 and set(changed.stdout.splitlines()) <= {"ROADMAP.md"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, default=CASE / "result.json")
    args = parser.parse_args()
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    raw = [json.loads(path.read_text(encoding="utf-8")) for path in args.raw]
    raw_by_key = {(row["case_path"], row["entry_point"]): row for row in raw}

    baseline_text = subprocess.run(
        ["git", "show", f"HEAD:{manifest['batch_file']}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    if hashlib.sha256(baseline_text.encode()).hexdigest() != manifest["selection_batch_sha256"]:
        raise SystemExit("branch-base batch does not match selection_batch_sha256")
    baseline = {
        (row["component"], row["path"]): row
        for row in (json.loads(line) for line in baseline_text.splitlines() if line.strip())
    }
    baseline_ledger_text = subprocess.run(
        ["git", "show", "HEAD:docs/corpora/tapenade-status.csv"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    baseline_ledger = {
        (row["component"], row["path"]): row
        for row in csv.DictReader(baseline_ledger_text.splitlines())
    }

    cases = []
    for selected in manifest["case"]:
        raw_row = raw_by_key[(selected["queue_path"], selected["entry_point"])]
        if raw_row["upstream_revision"] != manifest["upstream_revision"]:
            raise SystemExit(f"upstream revision mismatch for {selected['id']}")
        if not fortad_code_is_pinned(raw_row.get("fortad_revision"), manifest["fortad_revision"]):
            raise SystemExit(f"FortAD code revision is not pinned for {selected['id']}")
        batch = baseline[(selected["component"], selected["queue_path"])]
        if baseline_ledger[(selected["component"], selected["queue_path"])] ["status"] != "untriaged":
            raise SystemExit(f"selection row was already classified at branch base for {selected['id']}")
        if batch["candidate_status"] != selected["compiler_status"]:
            raise SystemExit(f"compiler evidence changed for {selected['id']}")

        sources = [selected["source"], *selected["references"]]
        exact = {source: compiler_check(source) for source in sources}
        if any(check["strict"]["status"] != "pass" for check in exact.values()):
            raise SystemExit(f"exact source strict compile failed for {selected['id']}")
        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py"), "--case", selected["oracle_case"]],
            capture_output=True,
            text=True,
            check=False,
        )
        if oracle.returncode:
            raise SystemExit(f"oracle failed for {selected['id']}: {oracle.stderr}")
        oracle_value = json.loads(oracle.stdout)[selected["oracle_case"]]
        modes = {
            mode: {
                name: engine(value, raw_row["result_dir"], mode, name, selected["source"])
                for name, value in probes.items()
            }
            for mode, probes in raw_row["probes"].items()
        }
        cases.append(
            {
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
                "exact_source_checks": exact,
                "source": selected["source"],
                "references": selected["references"],
                "source_reference_sha256": {path: sha256(UPSTREAM / path) for path in sources},
                "entry_point": selected["entry_point"],
                "selection": "modern-feature-score-then-queue-order-real-source-entry",
                "classification": selected["classification"],
                "closure": selected["closure"],
                "oracle_case": selected["oracle_case"],
                "upstream_revision": raw_row["upstream_revision"],
                "fortad_revision": manifest["fortad_revision"],
                "probe_fortad_revision": raw_row.get("fortad_revision"),
                "dependency_risk": raw_row["dependency_risk"],
                "dependency_hints": raw_row["dependency_hints"],
                "probe_status": raw_row["status"],
                "modes": modes,
                "independent_oracle": oracle_value,
            }
        )
    result = {
        "schema_version": 1,
        "shard_id": manifest["shard_id"],
        "queue_file": manifest["queue_file"],
        "batch_file": manifest["batch_file"],
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
