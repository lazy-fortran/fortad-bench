#!/usr/bin/env python3
"""Independent semantic oracle for the v544 declaration-only module."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NoReturn


MODULE_RE = re.compile(r"^module\s+(?!procedure\b)([a-z][a-z0-9_]*)$", re.I)
END_MODULE_RE = re.compile(r"^end\s+module(?:\s+[a-z][a-z0-9_]*)?$", re.I)
CALLABLE_RE = re.compile(
    r"^(?:(?:pure|elemental|recursive)\s+)?"
    r"(?:program|subroutine|function)\b",
    re.I,
)


def fail(message: str) -> NoReturn:
    raise SystemExit(f"oracle_status: fail\nreason: {message}")


def normalize(line: str) -> str:
    return re.sub(r"\s+", " ", line.strip()).lower()


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: oracle.py SOURCE")
    source = Path(sys.argv[1])
    if not source.is_file():
        fail(f"missing source {source}")

    expected_body = [
        "integer (kind=4), parameter :: c_intptr_t = 4",
        "type :: c_ptr",
        "private",
        "integer(c_intptr_t) :: ptr",
        "end type c_ptr",
        "type(c_ptr), parameter :: c_null_ptr = c_ptr(0)",
    ]
    modules: list[str] = []
    body: list[str] = []
    callable_units: list[str] = []
    current: str | None = None

    for line_number, raw_line in enumerate(
        source.read_text(encoding="utf-8").splitlines(), 1
    ):
        line = raw_line.split("!", 1)[0].strip()
        if not line:
            continue
        module = MODULE_RE.fullmatch(line)
        if module:
            if current is not None:
                fail(f"nested module at line {line_number}")
            current = module.group(1).lower()
            modules.append(current)
            continue
        if END_MODULE_RE.fullmatch(line):
            if current is None:
                fail(f"orphan module end at line {line_number}")
            current = None
            continue
        if CALLABLE_RE.match(line):
            callable_units.append(f"line {line_number}: {line}")
            continue
        if current is None:
            fail(f"statement outside module at line {line_number}: {line}")
        body.append(normalize(line))

    if current is not None:
        fail(f"unterminated module {current}")
    if modules != ["test"]:
        fail(f"module inventory {modules!r} != ['test']")
    if body != [normalize(line) for line in expected_body]:
        fail(f"module TEST declarations {body!r} changed")
    if callable_units:
        fail(f"callable or executable units found: {callable_units!r}")

    print("oracle_status: pass")
    print("oracle_kind: independent-module-type-declaration-semantic")
    print("module_count: 1")
    print("module_names: TEST")
    print("test_state: C_INTPTR_T=4; C_PTR%ptr=private INTEGER(C_INTPTR_T)")
    print("test_parameter: C_NULL_PTR=C_PTR(0)")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-entry-point")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
