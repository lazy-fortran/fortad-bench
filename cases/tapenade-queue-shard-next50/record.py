#!/usr/bin/env python3
"""Canonicalize the next50 exact Tapenade/FortAD probe records."""
from __future__ import annotations
import importlib.util, json, sys, tomllib
from pathlib import Path
CASE=Path(__file__).resolve().parent
SOURCE=CASE.parents[1]/"cases/tapenade-queue-shard-next48/record.py"
SPEC=importlib.util.spec_from_file_location("next49_record",SOURCE); assert SPEC and SPEC.loader
MODULE=importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(MODULE)
MODULE.CASE=CASE; MODULE.ROOT=CASE.parents[1]; MODULE.UPSTREAM=MODULE.ROOT/"upstream"/"tapenade"
def normalize_queue_file_case_paths() -> None:
    manifest=tomllib.loads((CASE/"manifest.toml").read_text(encoding="utf-8")); selected={(c["entry_point"],c["source"]):c for c in manifest["case"]}
    arguments=sys.argv[1:]
    for i,arg in enumerate(arguments):
        if arg!="--raw" or i+1>=len(arguments): continue
        path=Path(arguments[i+1]); value=json.loads(path.read_text(encoding="utf-8")); item=selected.get((value.get("entry_point"),value.get("source")))
        if item and value.get("case_path")!=item["queue_path"]:
            value["case_path"]=item["queue_path"]; path.write_text(json.dumps(value,indent=2,sort_keys=True)+"\n",encoding="utf-8")
if __name__=="__main__":
    normalize_queue_file_case_paths(); raise SystemExit(MODULE.main())
