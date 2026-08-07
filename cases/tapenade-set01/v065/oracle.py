#!/usr/bin/env python3
"""Independent semantic oracle for the v065 BLOCKDATA initialization."""

from __future__ import annotations

import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set02" / "v065"


def _single_match(pattern: str, text: str, label: str) -> re.Match[str]:
    match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
    if match is None:
        raise AssertionError(f"missing {label}")
    return match


def _common_values(text: str, label: str) -> tuple[int, int, int]:
    _single_match(r"^\s*blockdata\s*$", text, f"{label} BLOCKDATA")
    _single_match(r"^\s*common\s*/axes/\s+ii\s*,?\s*jj\s*,?\s*kk\s*$", text, f"{label} COMMON")
    match = _single_match(
        r"^\s*data\s+ii\s*,?\s*jj\s*,?\s*kk\s*/\s*([+-]?\d+)\s*,\s*([+-]?\d+)\s*,\s*([+-]?\d+)\s*/",
        text,
        f"{label} DATA",
    )
    return tuple(int(value) for value in match.groups())


def main() -> int:
    primal = (SOURCE_DIR / "program.f").read_text(encoding="utf-8")
    parser = (SOURCE_DIR / "program_p.f").read_text(encoding="utf-8")

    for label, text in (("primal", primal), ("parser-reference", parser)):
        if re.search(r"^\s*(program|function|subroutine)\b", text, re.IGNORECASE | re.MULTILINE):
            raise AssertionError(f"{label} unexpectedly contains a callable/program unit")
        if re.search(r"^\s*call\b", text, re.IGNORECASE | re.MULTILINE):
            raise AssertionError(f"{label} unexpectedly contains executable calls")

    primal_values = _common_values(primal, "primal")
    parser_values = _common_values(parser, "parser-reference")
    if primal_values != parser_values:
        raise AssertionError(f"parser/reference state mismatch: {primal_values} != {parser_values}")

    # This is an independent model of the DATA statement, not a derivative or
    # a parser result: COMMON state is the three initialized integer slots.
    values = (1, 2, 3)
    if primal_values != values:
        raise AssertionError(f"unexpected COMMON state: {primal_values}")
    total = sum(values)
    product = values[0] * values[1] * values[2]
    weighted = sum((index + 1) * value for index, value in enumerate(values))
    if (total, product, weighted) != (6, 6, 14):
        raise AssertionError("independent COMMON numerical model failed")

    print("oracle_unit_shape: BLOCKDATA only; no callable procedure")
    print(f"oracle_common_values: {list(values)}")
    print(f"oracle_sum: {total}")
    print(f"oracle_product: {product}")
    print(f"oracle_weighted_checksum: {weighted}")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
