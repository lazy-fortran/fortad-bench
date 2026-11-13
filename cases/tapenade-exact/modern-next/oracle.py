#!/usr/bin/env python3
"""Independent source/primal/refusal models for the modern-next shard.

These models do not read the upstream sources, generated products, or engine
diagnostics. They check the source-level dispatch/graph behavior and state why
the selected dynamic ownership boundary has no derivative-support claim.
"""

from __future__ import annotations

import argparse
import json


class Node:
    def __init__(self, value: int, parent: "Node | None" = None) -> None:
        self.value = value
        self.parent = parent
        self.next: Node | None = None
        self.child: Node | None = None
        self.alive = True


def _walk_and_update(root: Node) -> None:
    outer = root
    while outer is not None:
        inner = outer.child
        while inner is not None:
            inner.value = inner.value + 1 if inner.value > 1 else inner.value - 1
            inner = inner.next
        outer = outer.next


def _check_v344() -> dict:
    root = Node(0)
    first = Node(0, root)
    second = Node(0, root)
    first.child = Node(1, first)
    first.child.next = Node(3, first)
    second.child = Node(2, second)
    root.next = first
    first.next = second
    _walk_and_update(root.next)
    assert [first.child.value, first.child.next.value] == [0, 4]
    assert second.child.value == 3
    return {
        "status": "pass",
        "primal": {"model": "nested pointer-tree value update", "values": [0, 4, 3]},
        "derivative": {"status": "not-defined", "reason": "pointer association and owned target identity are not represented"},
        "refusal": {"status": "expected", "boundary": "nested pointer ownership"},
        "case": "v344-foo",
    }


def _check_f03typf02() -> dict:
    base_value = 1.0
    typ1_y = 0.0 + base_value + base_value
    typ2_y = 0.0 + base_value * 3.0
    assert typ1_y == 2.0 and typ2_y == 3.0
    return {
        "status": "pass",
        "primal": {"model": "abstract base plus type-extension dispatch", "typ1_y": typ1_y, "typ2_y": typ2_y},
        "derivative": {"status": "not-defined", "reason": "abstract polymorphic module context and dynamic dispatch are outside this probe's derivative map"},
        "refusal": {"status": "expected", "boundary": "abstract polymorphic module context"},
        "case": "f03typf02-foo",
    }


def _check_mvo35() -> dict:
    x = 2.0
    typ1_y = 1.0 * x
    typ2_val1 = 2.0 + x
    typ2_y = typ2_val1 * x
    assert typ1_y == 2.0 and typ2_val1 == 4.0 and typ2_y == 8.0
    return {
        "status": "pass",
        "primal": {"model": "select-type procedure-pointer dispatch", "typ1_y": typ1_y, "typ2_val1": typ2_val1, "typ2_y": typ2_y},
        "derivative": {"status": "not-defined", "reason": "procedure-pointer targets and dynamic polymorphic dispatch are not represented"},
        "refusal": {"status": "expected", "boundary": "polymorphic procedure-pointer invocation"},
        "case": "mvo35-foo",
    }


def _check_lh140() -> dict:
    # The source links aliases exactly as ``link(xc2, xc3, xc1)`` does.
    graph = {
        "cc1": {"x": 1.1, "next3": "cc3", "prev2": "cc2"},
        "cc2": {"x": 1.1, "next3": "cc3", "prev2": None},
        "cc3": {"x": 1.1, "next3": "cc2", "prev2": "cc1"},
    }
    graph["cc3"]["x"] = 1.72
    graph["cc1"]["x"] = graph["cc2"]["x"] * graph["cc3"]["x"] + 0.91
    graph["cc2"]["x"] = 0.91
    graph["cc3"]["x"] = graph["cc2"]["x"] * graph["cc2"]["x"]
    result = graph["cc3"]["x"] * graph["cc1"]["x"] + graph["cc1"]["x"] * graph["cc3"]["x"]
    assert abs(graph["cc1"]["x"] - 2.802) < 1.0e-12
    assert abs(graph["cc3"]["x"] - 0.8281) < 1.0e-12
    assert abs(result - 4.6406724) < 1.0e-12
    return {
        "status": "pass",
        "primal": {"model": "pointer-linked derived-object arithmetic", "cc1_x": graph["cc1"]["x"], "cc3_x": graph["cc3"]["x"], "result": result},
        "derivative": {"status": "not-defined", "reason": "pointer association storage identity and module-owned aliases are not represented"},
        "refusal": {"status": "expected", "boundary": "pointer alias lifetime"},
        "case": "lh140-compute",
    }


CHECKS = {
    "v344-foo": _check_v344,
    "f03typf02-foo": _check_f03typf02,
    "mvo35-foo": _check_mvo35,
    "lh140-compute": _check_lh140,
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
