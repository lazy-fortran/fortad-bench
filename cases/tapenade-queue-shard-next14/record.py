#!/usr/bin/env python3
"""Canonicalize next14 exact-source Tapenade/FortAD probe records."""

from __future__ import annotations

import importlib.util
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "tapenade-queue-shard-next13" / "record.py"
SPEC = importlib.util.spec_from_file_location("next13_record", SOURCE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load recorder: {SOURCE}")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
# next13 is itself a thin wrapper around next8.  Use its canonical next8
# implementation, but point the inner recorder at this shard's manifest.
MODULE.MODULE.CASE = Path(__file__).resolve().parent

if __name__ == "__main__":
    raise SystemExit(MODULE.MODULE.main())
