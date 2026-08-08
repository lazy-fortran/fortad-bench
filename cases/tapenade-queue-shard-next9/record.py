"""Canonicalize next9 probe records using the established shard recorder."""

from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "cases/tapenade-queue-shard-next8/record.py"
SPEC = importlib.util.spec_from_file_location("next8_record", SOURCE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load recorder: {SOURCE}")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
MODULE.CASE = Path(__file__).resolve().parent


if __name__ == "__main__":
    raise SystemExit(MODULE.main())
