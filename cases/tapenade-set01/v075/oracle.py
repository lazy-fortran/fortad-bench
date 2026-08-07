#!/usr/bin/env python3
"""Independent semantic/numerical oracle for the v075 type-only source."""

from __future__ import annotations

import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "nonRegressions" / "set05" / "v075" / "program.f90"


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    assert re.search(r"^\s*module\s+blocks\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*end\s+module\s+blocks\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*type\s*,\s*public\s*::\s*block\b.*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*end\s+type\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*implicit\s+none\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*private\s*$", source, re.IGNORECASE | re.MULTILINE)

    scalar_names = ["block_id", "local_id", "ib", "ie", "jb", "je", "iblock", "jblock"]
    scalar_line = re.search(
        r"integer\s*\(\s*4\s*\)\s*::\s*&?\s*(.*?)\n\s*integer",
        source,
        re.IGNORECASE | re.DOTALL,
    )
    assert scalar_line is not None
    scalar_text = re.sub(r"[&!].*", "", scalar_line.group(1))
    scalar_text = re.sub(r"\s+", "", scalar_text)
    assert scalar_text == ",".join(scalar_names)
    assert re.search(r"integer\s*\(\s*4\s*\).*i_glob\s*\(\s*5\s*\).*j_glob\s*\(\s*6\s*\)", source, re.IGNORECASE | re.DOTALL)
    assert not re.search(r"^\s*(program|subroutine|function)\b", source, re.IGNORECASE | re.MULTILINE)

    values = list(range(1, 9)) + list(range(101, 106)) + list(range(201, 207))
    assert len(values) == 19
    weighted_checksum = sum((index + 1) * value for index, value in enumerate(values))
    assert weighted_checksum == 26043

    print("oracle_module: BLOCKS with public derived type BLOCK")
    print("oracle_component_groups: 8 scalar integer(4), i_glob(5), j_glob(6)")
    print("oracle_component_count: 19")
    print(f"oracle_layout_weighted_checksum: {weighted_checksum}")
    print("oracle_entry_point: none; no executable numerical function exists")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
