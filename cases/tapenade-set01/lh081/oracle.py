#!/usr/bin/env python3
"""Independent call-graph and derivative-propagation oracle for lh081."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def compact(path: Path) -> str:
    return re.sub(r"\s+", "", path.read_text(encoding="latin-1").lower())


def check_source(source: Path) -> None:
    text = compact(source / "program.f")
    required = (
        "subroutinetest(y,f,jac,pjac)",
        "externalf,jac,pjac",
        "callpjac(y,jac)",
        "subroutinetest2(a,f,jac,pjac)",
        "calltest(a,f,jac,pjac)",
    )
    missing = [fragment for fragment in required if fragment not in text]
    if missing:
        raise SystemExit(f"source call graph changed; missing {missing!r}")
    names = re.findall(
        r"subroutine\s+([a-z0-9_]+)",
        source.joinpath("program.f").read_text(encoding="latin-1").lower(),
    )
    if names != ["test", "test2"]:
        raise SystemExit(f"lh081 must contain exactly test and test2, got {names!r}")
    print("oracle_source_call_graph: pass test2->test->pjac(jac), external f/jac/pjac")


def check_forward(path: Path) -> None:
    text = compact(path)
    required = (
        "subroutinetest2_d(a,ad,f,jac,jac_d,pjac,pjac_d)",
        "calltest_d(a,ad,f,jac,jac_d,pjac,pjac_d)",
        "subroutinetest_d(y,yd,f,jac,jac_d,pjac,pjac_d)",
        "callpjac_d(y,yd,jac,jac_d)",
    )
    if any(fragment not in text for fragment in required):
        raise SystemExit("fresh tangent artifact does not preserve the source call graph")
    print("oracle_forward_propagation: pass test2_d->test_d->pjac_d")


def check_reverse(path: Path) -> None:
    text = compact(path)
    required = (
        "subroutinetest2_b(a,ab,f,jac,jac_b,pjac,pjac_b)",
        "calltest_b(a,ab,f,jac,jac_b,pjac,pjac_b)",
        "subroutinetest_b(y,yb,f,jac,jac_b,pjac,pjac_b)",
        "callpjac_b(y,yb,jac,jac_b)",
    )
    if any(fragment not in text for fragment in required):
        raise SystemExit("fresh adjoint artifact does not preserve the source call graph")
    print("oracle_reverse_propagation: pass test2_b->test_b->pjac_b")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("--forward", type=Path)
    parser.add_argument("--reverse", type=Path)
    args = parser.parse_args()
    check_source(args.source_dir.resolve())
    if args.forward is not None:
        check_forward(args.forward.resolve())
    if args.reverse is not None:
        check_reverse(args.reverse.resolve())
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
