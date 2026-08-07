#!/usr/bin/env python3
"""Independent semantic inventory for the v317 no-entry boundary."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


MODULE = re.compile(r"^module\s+m\s*$", re.IGNORECASE)
POINTER = re.compile(
    r"^real\s*,\s*pointer\s*::\s*(p1)\s*=>\s*null\(\)\s*$",
    re.IGNORECASE,
)
CALLABLE = re.compile(
    r"^(?:program|subroutine|function|recursive\s+subroutine|recursive\s+function)\b",
    re.IGNORECASE,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    args = parser.parse_args()

    lines = args.source.read_text(encoding="utf-8").splitlines()
    code = [line.split("!", 1)[0].strip() for line in lines]
    modules = [line for line in code if MODULE.fullmatch(line)]
    pointers = [match.group(1).lower() for line in code if (match := POINTER.fullmatch(line))]
    callable_units = [
        line
        for line in code
        if CALLABLE.match(line) and not line.lower().startswith("end ")
    ]
    contains_units = [line for line in code if line.lower() == "contains"]

    if len(modules) != 1:
        raise SystemExit("v317 module inventory changed")
    if pointers != ["p1"]:
        raise SystemExit("v317 pointer declaration changed")
    if callable_units or contains_units:
        raise SystemExit("v317 unexpectedly gained a callable or contained unit")

    print("module_count: 1")
    print("pointer_names: p1")
    print("null_initializer_count: 1")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-entry-point")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
