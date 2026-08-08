"""Independent behavioral and refusal-boundary oracles for next17."""

from __future__ import annotations

import argparse
import json
import math


def b05() -> dict[str, object]:
    # A reduced independent model of the final wave accumulation and output
    # storage.  The loop is intentionally modeled as a sequence, because the
    # reverse derivative needs one contribution per iteration.
    eigenvalues = [0.25, 0.5, 0.75, 1.0]
    strengths = [2.0, -1.0, 0.5, 3.0]
    right_first_component = [1.0, 1.0, 0.0, 1.0]
    fd = [0.0] * 4
    history = []
    for eigenvalue, strength, component in zip(eigenvalues, strengths, right_first_component):
        contribution = eigenvalue * strength * component
        history.append(contribution)
        fd[0] += contribution
    assert history == [0.5, -0.5, 0.0, 3.0]
    assert fd[0] == 3.0
    assert len(history) == len(eigenvalues)
    return {
        "status": "pass",
        "wave_sum": fd[0],
        "iteration_history": history,
        "boundary": "reverse wave accumulation requires per-iteration storage; generated interface remains unclaimed",
    }


def bd07() -> dict[str, object]:
    b = [[float(i + 1) for j in range(10)] for i in range(10)]
    c = [[float(2 * i + j + 1) for j in range(10)] for i in range(10)]
    a = [[b[i][j] * c[i][j] for j in range(10)] for i in range(10)]
    first_row = [100.0 + i for i in range(10)]
    second_column = [200.0 + i for i in range(10)]
    for j, value in enumerate(first_row):
        c[0][j] = value
    for i, value in enumerate(second_column):
        c[i][1] = value
    a = [[a[i][j] + b[i][j] * c[i][j] for j in range(10)] for i in range(10)]
    assert a[0][0] == 1.0 + 1.0 * 100.0
    assert a[9][1] == 10.0 * 20.0 + 10.0 * 209.0
    return {
        "status": "pass",
        "shape": [10, 10],
        "read_overwrites": {"row_1": first_row, "column_2": second_column},
        "boundary": "active READ statements change primal state and block a derivative contract",
    }


def ht01() -> dict[str, object]:
    x = 1.5
    n1, n2, i = 5, 3, 1
    line = list("\t" + " " * 131)
    if n1 % n2 == 0:
        x = 2.0 * x
    n1 = min(n1, n2) - 1
    if line[i - 1] == "\t":
        line[i - 1] = " "
    # FOO is deliberately unresolved; this oracle checks only defined local
    # control flow and character storage, not an invented external derivative.
    y = x * x
    assert n1 == 2 and x == 1.5 and line[0] == " " and math.isfinite(y)
    return {
        "status": "pass",
        "n1": n1,
        "x_squared": y,
        "first_character": line[0],
        "boundary": "character substring assignment and unresolved external FOO",
    }


def lh043() -> dict[str, object]:
    x = 2.0
    y = 3.0
    ipas, nmax = 2, 4
    visited = list(range(nmax, 0, -ipas))
    for i in visited:
        x += y / float(i)
    external_input = x
    # Independent models of the visible local functions.
    func2 = external_input if external_input >= 0.0 else 0.0
    result = 9000.0 + (func2 + 1.0)
    assert visited == [4, 2] and x == 4.25 and result == 9005.25
    return {
        "status": "pass",
        "visited_indices": visited,
        "common_y": y,
        "result_after_local_functions": result,
        "boundary": "legacy labeled DO plus COMMON mutable state and unresolved EXTERNAL",
    }


ORACLES = {
    "B05-flux-interface-storage": b05,
    "bd07-array-read-boundary": bd07,
    "ht01-character-substring": ht01,
    "lh043-labeled-do-common": lh043,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = {args.case: ORACLES[args.case]()} if args.case else {name: fn() for name, fn in ORACLES.items()}
    print(json.dumps(selected, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
