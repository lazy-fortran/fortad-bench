#!/usr/bin/env python3
"""Independent semantic inventory for the v360 module-only boundary."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NoReturn


END_MODULE_RE = re.compile(r"end\s+module(?:\s+[a-z][a-z0-9_]*)?", re.IGNORECASE)
USE_RE = re.compile(r"use\s+([a-z][a-z0-9_]*)", re.IGNORECASE)
CALLABLE_RE = re.compile(
    r"(?:^|\s)(?:program|subroutine|function)\b", re.IGNORECASE
)


def fail(message: str) -> NoReturn:
    raise SystemExit(f"oracle_status: fail\nreason: {message}")


def normalized(line: str) -> str:
    return re.sub(r"\s+", " ", line.strip()).lower()


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: oracle.py SOURCE")
    source = Path(sys.argv[1])
    if not source.is_file():
        fail(f"missing source {source}")

    modules: list[str] = []
    uses: list[tuple[str, str]] = []
    declarations: dict[tuple[str, str], str] = {}
    current: str | None = None
    callable_units: list[str] = []

    expected_declarations = {
        ("m0", "m0_i"): "integer :: m0_i=2",
        ("m1", "gm_levels"): "integer, parameter :: gm_levels = 6",
        ("m1", "gm_show"): (
            "logical, private, dimension(gm_levels) :: gm_show = .false."
        ),
        ("m1", "gm_unit"): "integer,private :: gm_unit=6",
    }

    for line_number, raw_line in enumerate(
        source.read_text(encoding="utf-8").splitlines(), 1
    ):
        line = raw_line.split("!", 1)[0].strip()
        if not line:
            continue
        if CALLABLE_RE.search(line):
            callable_units.append(f"line {line_number}: {line}")
            continue
        if END_MODULE_RE.fullmatch(line):
            if current is None:
                fail(f"orphan module end at line {line_number}")
            current = None
            continue
        module = re.fullmatch(r"module\s+([a-z][a-z0-9_]*)", line, re.IGNORECASE)
        if module:
            if current is not None:
                fail(f"nested module at line {line_number}")
            current = module.group(1).lower()
            modules.append(current)
            continue
        if current is None:
            fail(f"statement outside module at line {line_number}: {line}")
        use = USE_RE.fullmatch(line)
        if use:
            uses.append((current, use.group(1).lower()))
            continue
        compact = normalized(line)
        for key, expected in expected_declarations.items():
            if key[0] == current and compact == normalized(expected):
                declarations[key] = compact
                break
        else:
            fail(f"unexpected declaration at line {line_number}: {line}")

    if current is not None:
        fail(f"unterminated module {current}")
    if modules != ["m0", "m1"]:
        fail(f"module inventory {modules!r} != ['m0', 'm1']")
    if uses != [("m1", "m0")]:
        fail(f"module uses {uses!r} != [('m1', 'm0')]")
    if set(declarations) != set(expected_declarations):
        fail(f"declaration inventory {sorted(declarations)!r} changed")
    if callable_units:
        fail(f"callable or executable units found: {callable_units!r}")

    print("oracle_status: pass")
    print("oracle_kind: independent-module-declaration-semantic")
    print("module_count: 2")
    print("module_names: M0,M1")
    print("module_use: M1 USE M0")
    print("declarations: M0.m0_i=2 M1.gm_levels=6 M1.gm_show=.false. M1.gm_unit=6")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-entry-point")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
