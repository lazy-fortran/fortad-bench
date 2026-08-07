#!/usr/bin/env python3
"""Independent semantic oracle for the v147 no-entry classification."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ENTRY = re.compile(
    r"^\s*(?:program|subroutine|(?:pure\s+|elemental\s+|recursive\s+)?function)\b",
    re.I,
)
MODULE = re.compile(r"^\s*module\s+(?!procedure\b)([a-z_]\w*)\s*$", re.I)
END_MODULE = re.compile(r"^\s*end\s+module\b", re.I)


def inspect(source: str) -> tuple[str, str]:
    lines = [line.split("!", 1)[0].rstrip() for line in source.splitlines()]
    modules = [match.group(1).lower() for line in lines if (match := MODULE.match(line))]
    entries = [line.strip() for line in lines if ENTRY.match(line)]
    if modules != ["a"] or entries:
        raise AssertionError(f"unexpected module/entry inventory: {modules=} {entries=}")
    if any(re.match(r"^\s*contains\b", line, re.I) for line in lines):
        raise AssertionError("module A unexpectedly has a CONTAINS section")
    if not any(END_MODULE.match(line) for line in lines):
        raise AssertionError("module A has no end statement")
    if not any(re.match(r"^\s*logical\s*,\s*dimension\s*\(:\)\s*,\s*pointer\s*::\s*ico\s*$", line, re.I) for line in lines):
        raise AssertionError("module A lost its logical pointer declaration")
    if not any(re.match(r"^\s*type\s+BCDataType\s*$", line, re.I) for line in lines):
        raise AssertionError("module A lost its derived type declaration")
    if not any(re.match(r"^\s*type\s*\(\s*BCDataType\s*\)\s*,\s*dimension\s*\(:\)\s*,\s*pointer\s*::\s*BCData\s*$", line, re.I) for line in lines):
        raise AssertionError("module A lost its derived-type pointer declaration")
    return "module-only-no-entry-point", "data-only-pointer-module"


def main() -> None:
    source_path = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).with_name("program.f90")
    classification, boundary = inspect(source_path.read_text(encoding="utf-8"))
    print(f"oracle_status: pass classification={classification} boundary={boundary}")


if __name__ == "__main__":
    main()
