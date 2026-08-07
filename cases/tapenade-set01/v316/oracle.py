#!/usr/bin/env python3
"""Independent semantic inventory for the v316 no-entry-point boundary."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


POINTER = re.compile(
    r"^\s*real\s*,\s*pointer\s*::\s*(p[1-4])\s*(=>|=)\s*(.+?)\s*$",
    re.IGNORECASE,
)
CALLABLE = re.compile(
    r"^\s*(program|subroutine|function|recursive\s+subroutine|recursive\s+function)\b",
    re.IGNORECASE,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    args = parser.parse_args()

    lines = args.source.read_text(encoding="utf-8").splitlines()
    code = [line.split("!", 1)[0].strip() for line in lines]
    modules = [line for line in code if re.match(r"^module\s+m\s*$", line, re.I)]
    pointers = []
    for line in code:
        match = POINTER.match(line)
        if match:
            pointers.append((match.group(1).lower(), match.group(2), match.group(3).lower()))

    callable_units = [line for line in code if CALLABLE.match(line)]
    names = [name for name, _, _ in pointers]
    invalid_patterns = [
        (name == "p2" and operator == "=" and rhs == "null()")
        or (name == "p3" and operator == "=>" and rhs == "p1")
        or (name == "p4" and operator == "=" and rhs == "p1")
        for name, operator, rhs in pointers
    ]

    if len(modules) != 1 or names != ["p1", "p2", "p3", "p4"]:
        raise SystemExit("v316 module/pointer inventory changed")
    if len(callable_units) != 0:
        raise SystemExit("v316 unexpectedly gained a callable unit")
    if sum(invalid_patterns) != 3:
        raise SystemExit("v316 invalid initializer inventory changed")

    print("module_count: 1")
    print("pointer_names: p1,p2,p3,p4")
    print("invalid_initializer_pattern_count: 3")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-entry-point")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
