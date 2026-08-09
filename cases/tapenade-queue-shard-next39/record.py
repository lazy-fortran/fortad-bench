#!/usr/bin/env python3
"""Canonicalize next39's exact Tapenade/FortAD probe records."""

from __future__ import annotations

import csv
import hashlib
import importlib.util
import subprocess
import tomllib
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[1]
SOURCE = ROOT / "cases" / "tapenade-queue-shard-next-modern" / "record.py"
SPEC = importlib.util.spec_from_file_location("next_modern_record", SOURCE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load recorder: {SOURCE}")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
MODULE.CASE = CASE


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


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
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    _check_branch_base(manifest)
    return MODULE.main()


if __name__ == "__main__":
    raise SystemExit(main())
