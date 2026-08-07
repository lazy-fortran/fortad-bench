#!/usr/bin/env python3
"""Independent semantic oracle for the empty lh000 corpus row."""

from __future__ import annotations

import argparse
from pathlib import Path


REFUSAL = (
    "1 Command: No root unit to differentiate\n"
    "2 File: The code provided does not contain a top procedure\n"
)
SOURCE_FILES = ("program.f", "program.f90")
REFUSAL_FILES = (
    "program_b.msg",
    "program_bv.msg",
    "program_d.msg",
    "program_db.msg",
    "program_dv.msg",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    source_root = args.source_root.resolve()

    for name in SOURCE_FILES:
        source = source_root / name
        if source.read_bytes() != b"":
            raise SystemExit(f"{name} is not exactly empty")
        print(f"oracle_{name}: empty-source")

    parser_message = source_root / "program_p.msg"
    if parser_message.read_bytes() != b"":
        raise SystemExit("program_p.msg is not exactly empty")
    print("oracle_program_p.msg: empty-parser-reference")

    for name in REFUSAL_FILES:
        message = (source_root / name).read_text(encoding="utf-8")
        if message != REFUSAL:
            raise SystemExit(f"{name} does not preserve the exact no-entry refusal")
        print(f"oracle_{name}: no-entry-refusal")

    print("oracle_entry_point: none")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
