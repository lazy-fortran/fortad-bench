#!/usr/bin/env python3
"""Independent semantic/layout oracle for the v201 module-only row."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ENTRY = re.compile(
    r"^\s*(?:program|subroutine|(?:pure\s+|elemental\s+|recursive\s+)?function)\b",
    re.IGNORECASE,
)
MODULE = re.compile(r"^\s*module\s+(?!procedure\b)([a-z_]\w*)\s*$", re.IGNORECASE)


def main() -> int:
    source_path = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).with_name("program.f90")
    raw = source_path.read_text(encoding="utf-8")
    lines = [line.split("!", 1)[0].rstrip() for line in raw.splitlines()]
    code = re.sub(r"\s+", " ", " ".join(line.replace("&", " ") for line in lines)).strip()

    modules = [match.group(1).lower() for line in lines if (match := MODULE.match(line))]
    entries = [line.strip() for line in lines if ENTRY.match(line)]
    assert modules == ["test"], f"unexpected modules: {modules!r}"
    assert not entries, f"unexpected callable entries: {entries!r}"
    assert re.search(r"\bimplicit\s+none\b", code, re.IGNORECASE)
    assert re.search(
        r"integer\s*\*\s*4\s*,\s*parameter\s*::\s*nspchnl\s*=\s*2001\s*,\s*ncomp0\s*=\s*10",
        code,
        re.IGNORECASE,
    )
    assert re.search(
        r"real\s*\*\s*8\s*,\s*dimension\s*\(\s*2\s*:\s*nspchnl\s*,\s*20\s*:\s*nspchnl\s*\)\s*::\s*acoef1",
        code,
        re.IGNORECASE,
    )
    assert re.search(
        r"real\s*\*\s*8\s*,\s*dimension\s*\(\s*ncomp0\s*:\s*nspchnl\s*,\s*1\s*:\s*4\s*\)\s*::\s*phis",
        code,
        re.IGNORECASE,
    )
    assert re.search(
        r"real\s*\*\s*8\s*,\s*dimension\s*\(\s*1\s*:\s*nspchnl\s*\)\s*::\s*refr",
        code,
        re.IGNORECASE,
    )
    assert not re.search(r"\bcontains\b", code, re.IGNORECASE)

    nspchnl = 2001
    ncomp0 = 10
    shapes = {
        "acoef1": (nspchnl - 2 + 1, nspchnl - 20 + 1),
        "phis": (nspchnl - ncomp0 + 1, 4),
        "refr": (nspchnl,),
    }
    counts = {name: _product(shape) for name, shape in shapes.items()}
    total = sum(counts.values())
    checksum = sum((index + 1) * count for index, count in enumerate(counts.values()))
    assert counts == {"acoef1": 3_964_000, "phis": 7_968, "refr": 2_001}
    assert total == 3_973_969
    assert checksum == 3_985_939

    print("oracle_module: TEST with IMPLICIT NONE and no callable entry")
    print("oracle_entry_points: none")
    print("oracle_acoef1_shape: 2000x1982")
    print("oracle_phis_shape: 1992x4")
    print("oracle_refr_shape: 2001")
    print(f"oracle_real_element_count: {total}")
    print(f"oracle_shape_checksum: {checksum}")
    print("oracle_status: pass")
    return 0


def _product(shape: tuple[int, ...]) -> int:
    result = 1
    for extent in shape:
        result *= extent
    return result


if __name__ == "__main__":
    raise SystemExit(main())
