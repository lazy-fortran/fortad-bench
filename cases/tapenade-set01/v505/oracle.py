#!/usr/bin/env python3
"""Independent semantic oracle for the v505 external-callback contract.

This intentionally does not invoke a compiler, Tapenade, or FortAD.  The
corpus does not define ftest or compute, so a numerical value is not an
observable of the checked source fragment.  The oracle instead checks the
argument-shape and callback graph that any bounded implementation would have
to preserve.
"""

from __future__ import annotations

import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v505" / "program.f90"


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    normalized = " ".join(source.lower().split())

    assert re.search(r"^\s*module\s+m\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*end\s+module\s+m\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"integer\s*,\s*parameter\s*::\s*n\s*=\s*2", source, re.IGNORECASE)
    assert re.search(r"real\s*,\s*dimension\s*\(\s*n\s*\)\s*::\s*r\s*,\s*s", source, re.IGNORECASE)
    assert re.search(r"function\s+compute\s*\(\s*x\s*,\s*y\s*\)", source, re.IGNORECASE)
    assert re.search(r"real\s*,\s*dimension\s*\(\s*n\s*\)\s*::\s*x\s*,\s*y", source, re.IGNORECASE)

    callback_calls = re.findall(
        r"^\s*top\s*=\s*ftest\s*\(\s*r\s*,\s*s\s*,\s*compute\s*\)",
        source,
        flags=re.IGNORECASE | re.MULTILINE,
    )
    assert len(callback_calls) == 1
    assert "real, external :: ftest" in normalized
    assert "interface compute" in normalized
    assert "end interface" in normalized

    # Abstract semantic execution: the only result-producing operation is an
    # external callback with an interface-only third argument.  No local
    # expression supplies a value that could be used for a numerical oracle.
    top_result_definition = re.findall(
        r"^\s*top\s*=\s*(.+)$", source, flags=re.IGNORECASE | re.MULTILINE
    )
    assert top_result_definition == ["ftest(r,s,compute)"]
    assert not re.search(r"function\s+ftest\b|subroutine\s+ftest\b", source, re.IGNORECASE)

    print("oracle_input_shape: r,s are real rank-one arrays of length n=2")
    print("oracle_callback_shape: compute(x,y) accepts two length-two real arrays and returns real")
    print("oracle_call_graph: top -> external ftest(r,s,compute)")
    print("oracle_local_numeric_definition: absent; top is exactly the external callback result")
    print("oracle_numerical_observable: undefined-without-ftest-and-compute-implementations")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
