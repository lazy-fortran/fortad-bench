#!/usr/bin/env python3
"""Independent semantic oracle for the declaration-only v216 source."""

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

    modules: list[str] = []
    entries: list[str] = []
    current: str | None = None
    seen: dict[str, set[str]] = {"definition": set(), "rk": set()}
    expected = {
        "definition": {
            "integer, parameter :: wp = selected_real_kind(10,50)",
        },
        "rk": {
            "use definition",
            "implicit none",
            "private",
            "public :: wp",
            "real(kind=wp) :: t",
        },
    }

    for line_number, raw_line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.split("!", 1)[0].strip()
        if not line:
            continue
        module = MODULE_RE.match(line)
        if module:
            if current is not None:
                fail(f"nested module at line {line_number}")
            current = module.group(1).lower()
            modules.append(current)
            continue
        if END_MODULE_RE.match(line):
            if current is None:
                fail(f"orphan end module at line {line_number}")
            current = None
            continue
        if ENTRY_RE.match(line):
            entries.append(f"line {line_number}: {line}")
            continue
        if current is None:
            fail(f"non-module statement at line {line_number}: {line}")
        lowered = re.sub(r"\s+", " ", line).lower()
        if lowered not in expected[current]:
            fail(f"unexpected statement at line {line_number}: {line}")
        if lowered in seen[current]:
            fail(f"duplicate declaration at line {line_number}: {line}")
        seen[current].add(lowered)

    if current is not None:
        fail(f"unterminated module {current}")
    if modules != ["definition", "rk"]:
        fail(f"module order {modules!r} != ['definition', 'rk']")
    if entries:
        fail(f"callable or executable units found: {entries!r}")
    for module, declarations in expected.items():
        if seen[module] != declarations:
            fail(f"{module} declarations {seen[module]!r} != {declarations!r}")

    print("oracle_status: pass")
    print("oracle_kind: independent-module-declaration-semantic")
    print("module_count: 2")
    print("module_names: definition,rk")
    print("kind_parameter: wp=selected_real_kind(10,50)")
    print("private_module_real_state: rk%t")
    print("callable_or_executable_units: 0")
    print("derivative_domain: empty-no-entry-point")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
