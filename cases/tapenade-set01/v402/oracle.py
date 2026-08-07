#!/usr/bin/env python3
"""Independent semantic oracle for the invalid v402 source boundary."""

from __future__ import annotations

import re
import os
from pathlib import Path


UPSTREAM_CANDIDATE = Path(
    "/mnt/storage/code/lazy-fortran/fortad-bench/upstreams/tapenade-e59864c"
)
if not UPSTREAM_CANDIDATE.is_dir():
    UPSTREAM_CANDIDATE = Path(
        "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"
    )
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(UPSTREAM_CANDIDATE)))
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v402"
PRIMAL = (SOURCE_DIR / "program.f90").read_text(encoding="utf-8")
REVERSE = (SOURCE_DIR / "program_b.f90").read_text(encoding="utf-8")

signature = re.search(r"(?im)^\s*subroutine\s+timeloop\s*\(([^)]*)\)", PRIMAL)
call = re.search(r"(?im)^\s*call\s+timeloop\s*\(([^)]*)\)", PRIMAL)
if signature is None or call is None:
    raise AssertionError("could not locate timeloop signature and call")

formal_count = len([item for item in signature.group(1).split(",") if item.strip()])
actual_count = len([item for item in call.group(1).split(",") if item.strip()])
if (formal_count, actual_count) != (1, 0):
    raise AssertionError(
        f"unexpected timeloop arity: formal={formal_count} actual={actual_count}"
    )

if not re.search(r"(?im)^\s*use\s+diffsizes\b", REVERSE):
    raise AssertionError("stored reverse source does not import DIFFSIZES")
if (SOURCE_DIR / "diffsizes.f90").exists() or (SOURCE_DIR / "DIFFSIZES.f90").exists():
    raise AssertionError("v402 unexpectedly contains the DIFFSIZES module source")

print("oracle_status: pass")
print("oracle_obligations: timeloop-formal-1-actual-0 missing-diffsizes-module")
print("oracle_result: no standard-conforming numerical map; no port claimed")
