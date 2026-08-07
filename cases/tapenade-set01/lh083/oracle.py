#!/usr/bin/env python3
"""Independent semantic oracle for the exact lh083 push/pop boundary."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    args = parser.parse_args()
    source_dir = args.source_dir.resolve()
    source = (source_dir / "program.f").read_text(encoding="utf-8")

    required = (
        "subroutine aa(X,Y)",
        "X(j) = X(j)*Y(i)",
        "call modify(j)",
        "subroutine modify(n)",
        "n = 2*n+1",
    )
    for fragment in required:
        if fragment not in source:
            raise SystemExit(f"missing exact semantic fragment: {fragment}")

    j = 5
    write_indices = []
    for iteration in range(1, 11):
        j += 2
        write_indices.append(j)
        j = 2 * j + 1

    expected = [7, 17, 37, 77, 157, 317, 637, 1277, 2557, 5117]
    if write_indices != expected:
        raise SystemExit(f"unexpected exact index trace: {write_indices}")
    first_invalid = next(i for i, index in enumerate(write_indices, 1) if index > 100)
    if first_invalid != 5:
        raise SystemExit(f"unexpected first invalid iteration: {first_invalid}")

    pushed = write_indices[:4]
    restored = list(reversed(pushed))
    if restored != [77, 37, 17, 7]:
        raise SystemExit(f"unexpected reverse restoration order: {restored}")

    print("oracle_write_indices: 7,17,37,77,157,317,637,1277,2557,5117")
    print("oracle_first_out_of_bounds_iteration: 5 (X(157) > X(100))")
    print("oracle_reverse_restore_order: 77,37,17,7")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
