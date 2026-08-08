#!/usr/bin/env python3
"""Canonicalize four exact probe records into committed shard evidence."""
from __future__ import annotations
import argparse, csv, hashlib, json, subprocess, tempfile, tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UPSTREAM = ROOT / "upstream" / "tapenade"
CASE = Path(__file__).resolve().parent
FLAGS = ["-fsyntax-only", "-std=f2018", "-ffree-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface"]

def sha256(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def normalize(value, directory):
    value = (value or "").replace(directory, "$RESULT_DIR")
    return value if len(value) <= 1600 else "..." + value[-1600:]
def command(value, directory): return [item.replace(directory, "$RESULT_DIR") for item in value] if value else None
def exact_check(source):
    case = UPSTREAM / Path(source).parent
    p = subprocess.run(["gfortran", *FLAGS, "-I.", Path(source).name], cwd=case, capture_output=True, text=True, check=False)
    return {"status": "pass" if p.returncode == 0 else "refused", "returncode": p.returncode, "stderr": normalize(p.stderr, str(case))}
def generated_check(path, source):
    with tempfile.TemporaryDirectory(prefix="fortad-shard-mod-", dir="/var/tmp") as mod:
        base = subprocess.run(["gfortran", "-c", "-std=f2018", "-ffree-line-length-none", "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface", f"-J{mod}", str(UPSTREAM / source)], capture_output=True, text=True, check=False)
        if base.returncode:
            return {"status": "refused", "returncode": base.returncode, "stderr": normalize(base.stderr, str(path.parent))}
        p = subprocess.run(["gfortran", *FLAGS, f"-I{mod}", f"-J{mod}", str(path)], capture_output=True, text=True, check=False)
        return {"status": "pass" if p.returncode == 0 else "refused", "returncode": p.returncode, "stderr": normalize(p.stderr, str(path.parent))}
def engine(value, directory, mode, name, source):
    result = {"status": value.get("status"), "returncode": value.get("returncode"), "command": command(value.get("command"), directory), "generated": sorted(value.get("generated", [])), "stdout": normalize(value.get("stdout"), directory), "stderr": normalize(value.get("stderr"), directory), "generated_syntax": {}}
    output = Path(directory) / mode / name
    for generated in result["generated"]:
        if generated.endswith(".f90"):
            result["generated_syntax"][generated] = generated_check(output / generated, source)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, default=CASE / "result.json")
    args = parser.parse_args()
    manifest = tomllib.loads((CASE / "manifest.toml").read_text())
    raw = [json.loads(path.read_text(encoding="utf-8")) for path in args.raw]
    raw_by_key = {(row["case_path"], row["entry_point"]): row for row in raw}
    baseline_text = subprocess.run(["git", "show", f"HEAD:{manifest['batch_file']}"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    if hashlib.sha256(baseline_text.encode()).hexdigest() != manifest["selection_batch_sha256"]:
        raise SystemExit("branch-base batch does not match selection_batch_sha256")
    baseline = {(row["component"], row["path"]): row for row in (json.loads(line) for line in baseline_text.splitlines() if line.strip())}
    baseline_ledger_text = subprocess.run(["git", "show", f"HEAD:docs/corpora/tapenade-status.csv"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    baseline_ledger = {(row["component"], row["path"]): row for row in csv.DictReader(baseline_ledger_text.splitlines())}
    cases = []
    for selected in manifest["case"]:
        raw_row = raw_by_key[(selected["queue_path"], selected["entry_point"])]
        if raw_row["upstream_revision"] != manifest["upstream_revision"] or raw_row["fortad_revision"] != manifest["fortad_revision"]:
            raise SystemExit(f"revision mismatch for {selected['id']}")
        batch = baseline[(selected["component"], selected["queue_path"])]
        if baseline_ledger[(selected["component"], selected["queue_path"])] ["status"] != "untriaged":
            raise SystemExit(f"selection row was already classified at branch base for {selected['id']}")
        if batch["candidate_status"] != selected["compiler_status"]:
            raise SystemExit(f"compiler evidence changed for {selected['id']}")
        sources = [selected["source"], *selected["references"]]
        exact = {source: exact_check(source) for source in sources}
        if any(value["status"] != "pass" for value in exact.values()):
            raise SystemExit(f"exact source strict compile failed for {selected['id']}")
        oracle = subprocess.run(["python3", str(CASE / "oracle.py"), "--case", selected["oracle_case"]], capture_output=True, text=True, check=False)
        if oracle.returncode:
            raise SystemExit(f"oracle failed for {selected['id']}: {oracle.stderr}")
        oracle_value = json.loads(oracle.stdout)[selected["oracle_case"]]
        modes = {mode: {name: engine(value, raw_row["result_dir"], mode, name, selected["source"]) for name, value in probes.items()} for mode, probes in raw_row["probes"].items()}
        source_paths = sources
        cases.append({
            "id": selected["id"], "component": selected["component"], "queue_path": selected["queue_path"], "queue_rank": selected["queue_rank"], "queue_category": selected["queue_category"],
            "selection_score": selected["selection_score"], "selection_features": selected["selection_features"], "compiler_status": batch["candidate_status"], "compiler_files": batch["compiler_files"], "compiler_missing_source_files": batch["compiler_missing_source_files"], "compiler_extra_source_files": batch["compiler_extra_source_files"],
            "exact_source_checks": exact, "source": selected["source"], "references": selected["references"], "source_reference_sha256": {path: sha256(UPSTREAM / path) for path in source_paths}, "entry_point": selected["entry_point"], "selection": "modern-feature-score-then-queue-order-real-source-entry", "classification": selected["classification"], "closure": selected["closure"],
            "upstream_revision": raw_row["upstream_revision"], "fortad_revision": raw_row["fortad_revision"], "dependency_risk": raw_row["dependency_risk"], "dependency_hints": raw_row["dependency_hints"], "probe_status": raw_row["status"], "modes": modes, "independent_oracle": oracle_value,
        })
    result = {"schema_version": 1, "shard_id": manifest["shard_id"], "queue_file": manifest["queue_file"], "queue_sha256": manifest["selection_queue_sha256"], "batch_file": manifest["batch_file"], "batch_sha256": manifest["selection_batch_sha256"], "selection_queue_sha256": manifest["selection_queue_sha256"], "selection_batch_sha256": manifest["selection_batch_sha256"], "current_queue_sha256": sha256(ROOT / manifest["queue_file"]), "current_batch_sha256": sha256(ROOT / manifest["batch_file"]), "upstream_revision": manifest["upstream_revision"], "fortad_revision": manifest["fortad_revision"], "jobs": 4, "cases": cases}
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
