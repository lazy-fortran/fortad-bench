#!/usr/bin/env python3
"""Independent source-shape oracle for the vpf16 module-only case."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import NoReturn


DEFAULT_SOURCE = (
    Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
    / "nonRegressions"
    / "set11"
    / "vpf16"
    / "program.f90"
)


def fail(message: str) -> NoReturn:
    raise SystemExit(f"oracle_status: fail\nreason: {message}")


def main() -> int:
    if len(sys.argv) > 2:
        fail("usage: oracle.py [SOURCE]")
    source = Path(
        sys.argv[1]
        if len(sys.argv) == 2
        else os.environ.get("TAPENADE_SOURCE", str(DEFAULT_SOURCE))
    )
    if not source.is_file():
        fail(f"missing source {source}")

    lines = [
        line.split("!", 1)[0].strip()
        for line in source.read_text(encoding="utf-8").splitlines()
    ]
    lines = [line for line in lines if line]
    normalized = [re.sub(r"\s+", " ", line).lower() for line in lines]

    modules = re.findall(
        r"^module\s+([a-z][a-z0-9_]*)$",
        "\n".join(lines),
        re.IGNORECASE | re.MULTILINE,
    )
    if [name.lower() for name in modules] != ["esmf_calendarmod", "mo"]:
        fail(f"module inventory {modules!r} changed")
    if "contains" in normalized:
        fail("executable module section found")
    if any(
        re.match(r"^(program|subroutine|function)\b", line, re.IGNORECASE)
        for line in lines
    ):
        fail("callable or executable unit found")

    expected_lines = {
        "use esmf_calendarmod, only: esmf_calendar, esmf_calendar_dummy",
        "integer :: esmf_calendar_dummy",
        "type esmf_calendar",
        "logical :: set = .false.",
        "end type esmf_calendar",
        "private esmf_calendar_dummy",
        "private esmf_calendar",
    }
    if not expected_lines.issubset(set(normalized)):
        fail("module/use/declaration inventory is incomplete")
    if normalized.count("implicit none") != 2:
        fail("expected IMPLICIT NONE in both modules")
    if normalized.count("end module esmf_calendarmod") != 1 or normalized.count(
        "end module mo"
    ) != 1:
        fail("module terminators changed")

    print("oracle_status: pass")
    print("oracle_kind: independent-module-declaration-semantic")
    print("oracle_modules: ESMF_CalendarMod,mo")
    print("oracle_use: mo USE ESMF_CalendarMod ONLY ESMF_Calendar,ESMF_Calendar_dummy")
    print("oracle_declarations: ESMF_Calendar_dummy; ESMF_Calendar%Set=.false.; PRIVATE imports")
    print("oracle_entry_points: none")
    print("derivative_domain: empty-no-entry-point")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
