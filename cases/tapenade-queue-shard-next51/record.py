#!/usr/bin/env python3
"""Canonicalize next51 exact Tapenade/FortAD probe records."""
from __future__ import annotations

import importlib.util
import json
import sys
import tomllib
from pathlib import Path


CASE = Path(__file__).resolve().parent
SOURCE = CASE.parents[1] / "cases/tapenade-queue-shard-next48/record.py"
SPEC = importlib.util.spec_from_file_location("next48_record", SOURCE)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
MODULE.CASE = CASE
MODULE.ROOT = CASE.parents[1]
MODULE.UPSTREAM = MODULE.ROOT / "upstream" / "tapenade"


def normalize_queue_file_case_paths() -> None:
    """Alias file-valued queue paths to the probe's normalized case key."""
    manifest = tomllib.loads((CASE / "manifest.toml").read_text(encoding="utf-8"))
    selected = {(item["entry_point"], item["source"]): item for item in manifest["case"]}
    arguments = sys.argv[1:]
    for index, argument in enumerate(arguments):
        if argument != "--raw" or index + 1 >= len(arguments):
            continue
        path = Path(arguments[index + 1])
        value = json.loads(path.read_text(encoding="utf-8"))
        key = (value.get("entry_point"), value.get("source"))
        item = selected.get(key)
        if item and value.get("case_path") != item["queue_path"]:
            value["case_path"] = item["queue_path"]
            path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    normalize_queue_file_case_paths()
    raise SystemExit(MODULE.main())
