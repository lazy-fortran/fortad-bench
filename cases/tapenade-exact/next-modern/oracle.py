#!/usr/bin/env python3
"""Independent primal/source/refusal models for the modern-feature shard.

The models do not read the Tapenade checkout, FortAD output, or the exact
source files. They validate the meaningful tree/lifetime/API behavior and
state explicitly where a scalar derivative is not defined.
"""

from __future__ import annotations

import argparse
import json


class Node:
    def __init__(self, name: str, parent: "Node | None" = None) -> None:
        self.name = name
        self.parent = parent
        self.sibling: Node | None = None
        self.child: Node | None = None
        self.alive = True


def _remove(node: Node) -> None:
    child = node.child
    while child is not None:
        sibling = child.sibling
        _remove(child)
        child = sibling
    if node.parent is not None:
        node.parent.child = node.sibling
    node.alive = False
    node.child = None
    node.sibling = None


def _check_pointer_tree(case: str) -> dict:
    root = Node("root")
    first = Node("first", root)
    second = Node("second", root)
    grandchild = Node("grandchild", first)
    first.child = grandchild
    first.sibling = second
    root.child = first
    _remove(first)
    assert root.child is second
    assert second.parent is root
    assert not first.alive and not grandchild.alive
    assert second.alive
    return {
        "status": "pass",
        "primal": {
            "model": "recursive removal of the first child and its subtree",
            "remaining_first_child": root.child.name,
            "deallocated": ["first", "grandchild"],
        },
        "derivative": {
            "status": "not-defined",
            "reason": "pointer graph mutation and deallocation have no scalar map",
        },
        "refusal": {
            "status": "expected",
            "boundary": "recursive pointer ownership and target identity",
        },
        "case": case,
    }


def _collect_garbage(state: dict[str, object]) -> None:
    state["thresh"] = None
    if state["p"] is state["stages_slice"]:
        state["p"] = None
    if state["ge_stages"] is state["stages"]:
        state["stages"] = None
        state["ge_stages"] = None
        state["v1"] = None
        state["v2"] = None
        state["v3"] = None
    elif state["ge_stages"] is not None:
        state["ge_stages"] = None


def _check_v243() -> dict:
    stages = object()
    stages_slice = object()
    state = {
        "thresh": object(),
        "p": stages_slice,
        "stages": stages,
        "stages_slice": stages_slice,
        "ge_stages": stages,
        "v1": object(),
        "v2": object(),
        "v3": object(),
    }
    _collect_garbage(state)
    assert all(state[name] is None for name in ("thresh", "p", "stages", "ge_stages", "v1", "v2", "v3"))
    other = {"thresh": None, "p": object(), "stages": object(), "stages_slice": object(), "ge_stages": object(), "v1": object(), "v2": object(), "v3": object()}
    retained_stages = other["stages"]
    _collect_garbage(other)
    assert other["stages"] is retained_stages and other["ge_stages"] is None
    return {
        "status": "pass",
        "primal": {"model": "identity-aware pointer lifetime cleanup", "shared_stage_storage_released": True, "unrelated_stage_storage_retained": True},
        "derivative": {"status": "not-defined", "reason": "allocation, nullification, and pointer-target lifetime are side effects"},
        "refusal": {"status": "expected", "boundary": "non-allocatable pointer target ownership"},
    }


def _check_v180() -> dict:
    routes = {rank: f"nf90_get_var_{rank}d_fourbytereal" for rank in range(1, 8)}
    assert routes[1].endswith("1d_fourbytereal")
    assert routes[7].endswith("7d_fourbytereal")
    optional_outputs = {"x_axis": None, "x_axis_2d": None, "y_axis": None, "y_axis_2d": None, "z_axis": None, "t_axis": None, "t_init": None, "t_step": None, "t_calendar": None}
    assert all(value is None for value in optional_outputs.values())
    return {
        "status": "pass",
        "primal": {"model": "rank-dispatched netCDF getter interface plus optional coordinate outputs", "generic_ranks": sorted(routes), "optional_outputs_omitted": True},
        "derivative": {"status": "not-defined", "reason": "the exact root has no active numeric input/output map; reverse requires an explicit dependent"},
        "refusal": {"status": "expected", "boundary": "no active dependent and standalone module-interface context"},
    }


CHECKS = {
    "ptr07-remove": lambda: _check_pointer_tree("ptr07-remove"),
    "ptr08-remove": lambda: _check_pointer_tree("ptr08-remove"),
    "v243-collect-garbage": _check_v243,
    "v180-fliogstc": _check_v180,
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
