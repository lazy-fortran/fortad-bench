#!/usr/bin/env python3
"""Independent source-shape oracle for the module-only v485 case."""

from __future__ import annotations

import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "nonRegressions" / "set07" / "v485" / "program.f90"


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    normalized = source.lower()

    assert re.findall(r"^\s*module\s+([a-z_][a-z0-9_]*)\s*$", source, re.IGNORECASE | re.MULTILINE) == [
        "FoX_dom_types"
    ]
    assert re.search(r"^\s*end\s+module\s+fox_dom_types\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert not re.search(r"^\s*(program|subroutine|function)\b", source, re.IGNORECASE | re.MULTILINE)
    assert not re.search(r"^\s*contains\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*type\s+nodelist\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*private\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(
        r"character\s*,\s*pointer\s*::\s*nodename\s*\(:\)\s*=>\s*null\s*\(\s*\)",
        normalized,
    )
    assert re.search(r"^\s*end\s+type\s+nodelist\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert normalized.count("module") == 2

    print("oracle_module: FoX_dom_types")
    print("oracle_type: private NodeList")
    print("oracle_component: character,pointer nodeName(:)=>null()")
    print("oracle_entry_points: none")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
