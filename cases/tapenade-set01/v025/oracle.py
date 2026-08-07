#!/usr/bin/env python3
"""Independent semantic oracle for the declaration-only v025 source."""

from __future__ import annotations

import re
import sys
from pathlib import Path


MODULE_RE = re.compile(r"^\s*module\s+([a-z][a-z0-9_]*)\s*$", re.IGNORECASE)
END_MODULE_RE = re.compile(r"^\s*end\s+module(?:\s+[a-z][a-z0-9_]*)?\s*$", re.IGNORECASE)
UNIT_RE = re.compile(
    r"^\s*(?:(?:pure|elemental|recursive)\s+)?"
    r"(?:program|subroutine|function)\b",
    re.IGNORECASE,
)
REAL_RE = re.compile(
    r"^\s*real\s*(?:,\s*([^:]+))?\s*::\s*"
    r"([a-z][a-z0-9_]*)\s*$",
    re.IGNORECASE,
)
SAVE_RE = re.compile(r"^\s*save(?:\s+|$)", re.IGNORECASE)

EXPECTED = {
    "a": {"x": "public", "y": "private"},
    "b": {"z": "public"},
    "c": {"u": "private"},
    "d": {"v": "public"},
    "e": {"w": "private"},
}


def fail(message: str) -> None:
    raise SystemExit(f"oracle_status: fail\nreason: {message}")


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: oracle.py SOURCE")
    source = Path(sys.argv[1])
    if not source.is_file():
        fail(f"missing source {source}")

    modules: dict[str, dict[str, str]] = {}
    current: str | None = None
    executable_or_callable: list[str] = []
    save_statements: dict[str, int] = {}
    save_attributes: dict[str, int] = {}

    for line_number, raw_line in enumerate(source.read_text().splitlines(), 1):
        line = raw_line.split("!", 1)[0].rstrip()
        if not line:
            continue
        match = MODULE_RE.match(line)
        if match:
            if current is not None:
                fail(f"nested module at line {line_number}")
            current = match.group(1).lower()
            modules[current] = {}
            continue
        if END_MODULE_RE.match(line):
            if current is None:
                fail(f"orphan end module at line {line_number}")
            current = None
            continue
        if UNIT_RE.match(line):
            executable_or_callable.append(f"line {line_number}: {line}")
            continue
        if current is None:
            fail(f"non-module statement at line {line_number}: {line}")
        real = REAL_RE.match(line)
        if real:
            attrs = {item.strip().lower() for item in (real.group(1) or "").split(",")}
            visibility = "private" if "private" in attrs else "public"
            name = real.group(2).lower()
            if name in modules[current]:
                fail(f"duplicate variable {current}%{name}")
            modules[current][name] = visibility
            if "save" in attrs:
                save_attributes[current] = save_attributes.get(current, 0) + 1
            continue
        if SAVE_RE.match(line):
            save_statements[current] = save_statements.get(current, 0) + 1
            continue
        fail(f"unexpected statement at line {line_number}: {line}")

    if current is not None:
        fail(f"unterminated module {current}")
    if modules != EXPECTED:
        fail(f"module declarations {modules!r} != expected {EXPECTED!r}")
    if executable_or_callable:
        fail(f"callable or executable units found: {executable_or_callable!r}")

    # Module variables have SAVE semantics even where the source does not use
    # an explicit SAVE statement.  This model is independent of the compiler
    # and checks observable storage class, not derivatives.
    saved = sum(len(variables) for variables in modules.values())
    if saved != 6:
        fail(f"expected six saved module variables, found {saved}")
    if save_statements != {"a": 1, "d": 1, "e": 1}:
        fail(f"unexpected explicit SAVE structure: {save_statements!r}")
    if save_attributes != {"b": 1, "c": 1}:
        fail(f"unexpected SAVE attributes: {save_attributes!r}")

    print("oracle_status: pass")
    print("oracle_kind: independent-module-storage-semantic")
    print("module_count: 5")
    print("saved_real_variable_count: 6")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-entry-point")
    print("explicit_save_statement_count: 3")
    print("save_attribute_count: 2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
