#!/usr/bin/env python3
"""Independent semantic oracle for the v320 declaration-only module."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NoReturn


MODULE_RE = re.compile(r"^module\s+(?!procedure\b)([a-z][a-z0-9_]*)$", re.I)
END_MODULE_RE = re.compile(r"^end\s+module(?:\s+[a-z][a-z0-9_]*)?$", re.I)
UNIT_RE = re.compile(r"^(?:(?:pure|elemental|recursive)\s+)?(?:program|subroutine|function)\b", re.I)
TYPE_RE = re.compile(r"^type\s+([a-z][a-z0-9_]*)$", re.I)
END_TYPE_RE = re.compile(r"^end\s+type(?:\s+[a-z][a-z0-9_]*)?$", re.I)


def fail(message: str) -> NoReturn:
    raise SystemExit(f"oracle_status: fail\nreason: {message}")


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: oracle.py SOURCE")
    source = Path(sys.argv[1])
    if not source.is_file():
        fail(f"missing source {source}")

    module_name: str | None = None
    current_type: str | None = None
    modules = 0
    callable_units: list[str] = []
    foobar_shape: tuple[int, ...] | None = None
    foobar_values: list[float] | None = None
    types: dict[str, tuple[list[str], int]] = {}

    for line_number, raw_line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.split("!", 1)[0].strip()
        if not line:
            continue
        module = MODULE_RE.fullmatch(line)
        if module:
            if module_name is not None or current_type is not None:
                fail(f"nested or duplicate module at line {line_number}")
            module_name = module.group(1).lower()
            modules += 1
            continue
        if END_MODULE_RE.fullmatch(line):
            if module_name is None or current_type is not None:
                fail(f"malformed module end at line {line_number}")
            continue
        if UNIT_RE.match(line):
            callable_units.append(f"line {line_number}: {line}")
            continue
        if module_name is None:
            fail(f"statement outside module at line {line_number}: {line}")

        type_start = TYPE_RE.fullmatch(line)
        if type_start:
            if current_type is not None:
                fail(f"nested type at line {line_number}")
            current_type = type_start.group(1).lower()
            types[current_type] = ([], 0)
            continue
        if END_TYPE_RE.fullmatch(line):
            if current_type is None:
                fail(f"orphan type end at line {line_number}")
            current_type = None
            continue

        lowered = re.sub(r"\s+", " ", line).lower()
        if current_type is not None:
            scalar = re.fullmatch(r"double precision\s+(.+)", lowered)
            if scalar:
                fields, vector_length = types[current_type]
                fields.extend(name.strip() for name in scalar.group(1).split(","))
                types[current_type] = (fields, vector_length)
                continue
            vector = re.fullmatch(r"double precision, dimension\((\d+)\) :: (\w+)", lowered)
            if vector:
                fields, _ = types[current_type]
                types[current_type] = (fields + [vector.group(2)], int(vector.group(1)))
                continue
            fail(f"unexpected type declaration at line {line_number}: {line}")

        declaration = re.fullmatch(
            r"double precision , dimension\((\d+)\) , private :: (\w+)", lowered
        )
        if declaration:
            foobar_shape = (int(declaration.group(1)),)
            continue
        data = re.fullmatch(r"data foobar /\s*([-+]?\d+(?:\.\d*)?)d0\s*,\s*([-+]?\d+(?:\.\d*)?)d0\s*/", lowered)
        if data:
            foobar_values = [float(data.group(1)), float(data.group(2))]
            continue
        fail(f"unexpected module statement at line {line_number}: {line}")

    expected_types = {
        "input": (["x", "y", "vector"], 5),
        "output": (["x", "y", "xdy", "xpy", "dot", "vector"], 5),
    }
    if modules != 1 or module_name != "test_typedef" or current_type is not None:
        fail(f"module inventory is modules={modules} name={module_name!r} type={current_type!r}")
    if foobar_shape != (2,) or foobar_values != [0.0, 1.0]:
        fail(f"foobar state is shape={foobar_shape!r} values={foobar_values!r}")
    if types != expected_types:
        fail(f"type layouts {types!r} != {expected_types!r}")
    if callable_units:
        fail(f"callable or executable units found: {callable_units!r}")

    print("oracle_status: pass")
    print("oracle_kind: independent-module-data-type-semantic")
    print("module_count: 1")
    print("module_name: test_typedef")
    print("private_data: foobar rank=1 extent=2 values=[0.0, 1.0]")
    print("derived_types: Input(x,y,vector[5]); Output(x,y,xdy,xpy,dot,vector[5])")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-callable-procedure")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
