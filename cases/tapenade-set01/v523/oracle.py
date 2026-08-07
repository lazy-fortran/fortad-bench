#!/usr/bin/env python3
"""Independent semantic inventory for the v523 empty-source boundary."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


UNIT = re.compile(r"^\s*(module|program|subroutine|function)\b", re.IGNORECASE)
EXECUTABLE = re.compile(
    r"^\s*(allocate|assign|backspace|call|close|continue|cycle|deallocate|do|"
    r"endfile|error\s+stop|exit|flush|forall|if|inquire|open|print|read|"
    r"return|rewind|stop|write)\b",
    re.IGNORECASE,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    args = parser.parse_args()

    raw = args.source.read_bytes()
    text = raw.decode("utf-8")
    code_lines = [line.split("!", 1)[0].strip() for line in text.splitlines()]
    nonblank = [line for line in code_lines if line]
    units = [line for line in nonblank if UNIT.match(line)]
    executable = [line for line in nonblank if EXECUTABLE.match(line)]

    if raw != b"":
        raise SystemExit("v523 source is no longer empty")
    if units or executable:
        raise SystemExit("v523 unexpectedly acquired Fortran semantics")

    print("source_byte_count: 0")
    print("module_units: 0")
    print("program_units: 0")
    print("callable_units: 0")
    print("executable_statements: 0")
    print("derivative_domain: empty-no-entry-point")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
