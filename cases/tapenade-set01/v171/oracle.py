#!/usr/bin/env python3
"""Independent structural/semantic oracle for the v171 module-only source."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NoReturn


MODULE_RE = re.compile(r"^\s*module\s+([a-z][a-z0-9_]*)\s*$", re.IGNORECASE)
END_MODULE_RE = re.compile(
    r"^\s*end\s+module(?:\s+[a-z][a-z0-9_]*)?\s*$", re.IGNORECASE
)
UNIT_RE = re.compile(
    r"^\s*(?:(?:pure|elemental|recursive)\s+)?"
    r"(?:program|subroutine|function)\b",
    re.IGNORECASE,
)
TYPE_START_RE = re.compile(r"^\s*type\s+([a-z][a-z0-9_]*)\s*$", re.IGNORECASE)
END_TYPE_RE = re.compile(
    r"^\s*end\s+type(?:\s+[a-z][a-z0-9_]*)?\s*$", re.IGNORECASE
)


def fail(message: str) -> NoReturn:
    raise SystemExit(f"oracle_status: fail\nreason: {message}")


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: oracle.py SOURCE")
    source = Path(sys.argv[1])
    if not source.is_file():
        fail(f"missing source {source}")

    module_name: str | None = None
    inside_module = False
    type_name: str | None = None
    type_fields: list[str] = []
    declarations: dict[str, str] = {}
    callable_units: list[str] = []

    for line_number, raw_line in enumerate(
        source.read_text(encoding="utf-8").splitlines(), 1
    ):
        line = raw_line.split("!", 1)[0].strip()
        if not line:
            continue
        module = MODULE_RE.match(line)
        if module:
            if inside_module or module_name is not None:
                fail(f"nested or duplicate module at line {line_number}")
            module_name = module.group(1).lower()
            inside_module = True
            continue
        if END_MODULE_RE.match(line):
            if not inside_module or type_name is not None:
                fail(f"malformed module end at line {line_number}")
            inside_module = False
            continue
        if UNIT_RE.match(line):
            callable_units.append(f"line {line_number}: {line}")
            continue
        if not inside_module:
            fail(f"statement outside module at line {line_number}: {line}")
        type_start = TYPE_START_RE.match(line)
        if type_start:
            if type_name is not None:
                fail(f"nested or duplicate type at line {line_number}")
            type_name = type_start.group(1).lower()
            continue
        if END_TYPE_RE.match(line):
            if type_name is None:
                fail(f"orphan type end at line {line_number}")
            type_name = None
            continue
        if type_name is not None:
            field = re.fullmatch(
                r"integer\s*::\s*(\w+)\s*=\s*(-?\d+)", line, re.IGNORECASE
            )
            if field:
                type_fields.append(f"{field.group(1).lower()}={field.group(2)}")
                continue
            fail(f"unexpected derived-type statement at line {line_number}: {line}")
        integer = re.fullmatch(
            r"integer\s*::\s*(\w+)\s*=\s*(-?\d+)", line, re.IGNORECASE
        )
        if integer:
            declarations[integer.group(1).lower()] = f"integer={integer.group(2)}"
            continue
        parameter = re.fullmatch(
            r"parameter\s*\(\s*(\w+)\s*=\s*(-?\d+(?:\.\d*)?)\s*\)",
            line,
            re.IGNORECASE,
        )
        if parameter:
            declarations[parameter.group(1).lower()] = f"parameter={parameter.group(2)}"
            continue
        fail(f"unexpected module statement at line {line_number}: {line}")

    if inside_module or module_name != "test" or type_name is not None:
        fail(
            f"unexpected module/type closure: module={module_name!r} "
            f"inside={inside_module} type={type_name!r}"
        )
    if type_fields != ["n=0"]:
        fail(f"derived type fields {type_fields!r} != ['n=0']")
    if declarations != {"m": "integer=1", "o": "parameter=2"}:
        fail(f"module declarations {declarations!r} do not match expected state")
    if callable_units:
        fail(f"callable or executable units found: {callable_units!r}")

    print("oracle_status: pass")
    print("oracle_kind: independent-module-declaration-semantic")
    print("module_count: 1")
    print("derived_type_count: 1")
    print("datatype_default: n=0")
    print("module_initialization: m=1 o=2")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-callable-procedure")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
