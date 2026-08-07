#!/usr/bin/env python3
"""Independent semantic oracle for the v362 declaration-only source."""

from __future__ import annotations

import re
import sys
from pathlib import Path


MODULE_RE = re.compile(r"^\s*module\s+(?!procedure\b)([a-z][a-z0-9_]*)\s*$", re.I)
END_MODULE_RE = re.compile(r"^\s*end\s+module(?:\s+[a-z][a-z0-9_]*)?\s*$", re.I)
ENTRY_RE = re.compile(
    r"^\s*(?:(?:pure|elemental|recursive)\s+)?"
    r"(?:program|subroutine|function)\b",
    re.I,
)


def fail(message: str) -> None:
    raise SystemExit(f"oracle_status: fail\nreason: {message}")


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: oracle.py SOURCE")
    source = Path(sys.argv[1])
    if not source.is_file():
        fail(f"missing source {source}")

    expected = {
        "m0": ["integer :: m0_i=2"],
        "m1": [
            "use m0",
            "integer, parameter :: gm_levels = 6",
            "logical, dimension(gm_levels) :: gm_show = .false.",
            "integer :: gm_unit=6",
            "private gm_show, gm_unit",
        ],
    }
    modules: list[str] = []
    declarations: dict[str, list[str]] = {"m0": [], "m1": []}
    callable_units: list[str] = []
    current: str | None = None

    for line_number, raw_line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.split("!", 1)[0].strip()
        if not line:
            continue
        module = MODULE_RE.match(line)
        if module:
            if current is not None:
                fail(f"nested module at line {line_number}")
            current = module.group(1).lower()
            if current not in expected:
                fail(f"unexpected module {current!r} at line {line_number}")
            modules.append(current)
            continue
        if END_MODULE_RE.match(line):
            if current is None:
                fail(f"orphan end module at line {line_number}")
            current = None
            continue
        if ENTRY_RE.match(line):
            callable_units.append(f"line {line_number}: {line}")
            continue
        if current is None:
            fail(f"non-module statement at line {line_number}: {line}")
        normalized = re.sub(r"\s+", " ", line).lower()
        declarations[current].append(normalized)

    if current is not None:
        fail(f"unterminated module {current}")
    if modules != ["m0", "m1"]:
        fail(f"module order {modules!r} != ['m0', 'm1']")
    if declarations != expected:
        fail(f"module declarations {declarations!r} != {expected!r}")
    if callable_units:
        fail(f"callable or executable units found: {callable_units!r}")

    print("oracle_status: pass")
    print("oracle_kind: independent-module-declaration-semantic")
    print("module_count: 2")
    print("module_names: m0,m1")
    print("m0_state: m0_i=2")
    print("m1_state: use=m0; gm_levels=6; private=gm_show,gm_unit")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-entry-point")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
