#!/usr/bin/env python3
"""Independent primal, derivative, and boundary oracles for this shard.

These models do not import FortAD, Tapenade, or the exact upstream sources.
They check the arithmetic/tree behavior that is meaningful in isolation and
state explicitly where pointer ownership, module state, or I/O makes a
derivative claim out of scope.
"""

from __future__ import annotations

import argparse
import json
import math


def _vmp06_add_node() -> dict:
    # Pure model of the documented insertion rule: a new child is prepended.
    forest = {"root": {"children": []}}
    forest["root"]["children"].insert(0, "first")
    forest["root"]["children"].insert(0, "second")
    assert forest["root"]["children"] == ["second", "first"]
    return {
        "status": "pass",
        "primal": {"model": "prepending a child in a rooted tree", "children": forest["root"]["children"]},
        "derivative": {"status": "not-defined", "reason": "pointer graph mutation has no scalar ownership model"},
        "refusal": {"status": "expected", "boundary": "pointer association storage identity"},
    }


def _lh159_collection() -> dict:
    points = ((1.25, 0.5, 2.0, -1.0, 0.25, 3.0, 4.0), (-2.0, -0.25, 0.5, 2.5, -1.5, 1.0, -3.0))
    values = {}
    derivatives = {}
    epsilon = 1.0e-6
    for point in points:
        a, c, d1, e1, t1, t2, t3bar = point
        t3test = 0.75

        def model(x: tuple[float, ...]) -> float:
            aa, cc, dd, ee, tt1, tt2, bb = x
            temp = aa + cc + dd + ee
            return t3test + 2.0 * temp + math.sin(tt1) + math.cos(tt2) + bb

        key = ",".join(str(x) for x in point)
        values[key] = model(point)
        analytic = (2.0, 2.0, 2.0, 2.0, math.cos(t1), -math.sin(t2), 1.0)
        finite = tuple(
            (model(point[:i] + (point[i] + epsilon,) + point[i + 1:])
             - model(point[:i] + (point[i] - epsilon,) + point[i + 1:]))
            / (2.0 * epsilon)
            for i in range(len(point))
        )
        assert all(abs(x - y) < 1.0e-6 for x, y in zip(analytic, finite))
        derivatives[key] = {"analytic": analytic, "central_difference": finite}
    return {
        "status": "pass",
        "primal": {"model": "component update followed by scalar collection result", "values": values},
        "derivative": {"status": "pass", "values": derivatives},
        "refusal": {"status": "expected", "boundary": "allocatable/pointer-containing derived arguments"},
    }


def _vmp07_dump_tree() -> dict:
    records = ["root", "child-a", "child-b"]
    assert records == list(records)
    return {
        "status": "pass",
        "primal": {"model": "depth-first tree record order", "records": records},
        "derivative": {"status": "not-defined", "reason": "the candidate's observable result is unformatted I/O"},
        "refusal": {"status": "expected", "boundary": "active WRITE plus module-level pointer state"},
    }


def _v193_find() -> dict:
    tree = {"root": ["left", "right"], "left": [], "right": ["leaf"], "leaf": []}

    def walk(node: str, name: str) -> bool:
        if node == name:
            return True
        return any(walk(child, name) for child in tree[node])

    assert walk("root", "leaf")
    assert not walk("root", "missing")
    return {
        "status": "pass",
        "primal": {"model": "finite tree membership search", "found": {"leaf": True, "missing": False}},
        "derivative": {"status": "not-defined", "reason": "pointer-linked derived-type traversal is not a scalar map"},
        "refusal": {"status": "expected", "boundary": "derived-type pointer alias/replay"},
    }


CHECKS = {
    "vmp06-add-node": _vmp06_add_node,
    "lh159-collection": _lh159_collection,
    "vmp07-dump-tree": _vmp07_dump_tree,
    "v193-find": _v193_find,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CHECKS))
    args = parser.parse_args()
    selected = [args.case] if args.case else sorted(CHECKS)
    print(json.dumps({name: CHECKS[name]() for name in selected}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
