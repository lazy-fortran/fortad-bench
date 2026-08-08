#!/usr/bin/env python3
"""Independent behavioral and refusal-boundary oracles for next20."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def lh114() -> dict[str, object]:
    n = 4
    a = [float(i) for i in range(101)]
    tangent = [0.0] * 101
    tangent[1:5] = [1.0, -2.0, 0.5, 3.0]
    for i in range(1, n + 1):
        a[i] = 2.0 * a[i]
        tangent[i] = 2.0 * tangent[i]
    n2 = 2 * n
    a[n2] = 3.0 * a[n2]
    tangent[n2] = 3.0 * tangent[n2]
    assert a[1:5] == [2.0, 4.0, 6.0, 8.0]
    assert a[8] == 24.0 and tangent[8] == 0.0
    assert tangent[1:5] == [2.0, -4.0, 1.0, 6.0]
    return {"status": "pass", "n_after": n2, "outputs": {"a1": a[1], "a4": a[4], "a8": a[8]}, "jvp": {"a1": tangent[1], "a4": tangent[4], "a8": tangent[8]}, "boundary": "automatic reverse dependent inference"}


def lh115() -> dict[str, object]:
    def prospect(x: float, y: float, z: float) -> float:
        return x * y

    x, y, z = 2.0, -3.0, 7.0
    z_after = prospect(x, y, z)
    dx, dy = 0.25, -0.5
    dz = y * dx + x * dy
    assert z_after == -6.0 and dz == -1.75
    source = (Path(__file__).parents[2] / "upstream/tapenade/nonRegressions/set01/lh115/program.f").read_text().lower()
    assert "call prospect(tv(5), t3(6), t4(7))" in source
    assert "call prospect(t3(i), tx(i), t4(i))" in source
    return {"status": "pass", "prospect": {"z": z_after, "dz": dz}, "boundary": "mutating procedure-call actuals require plain writable variables", "undefined_inputs": ["c1", "c2", "tx(0)"]}


def lh117() -> dict[str, object]:
    common_c = 2.0
    x, z, u = 3.0, 5.0, 0.25
    z_after = z + x * common_c + u
    t_after = 1.5 * common_c
    assert z_after == 11.25 and t_after == 3.0
    source = (Path(__file__).parents[2] / "upstream/tapenade/nonRegressions/set01/lh117/program.f").read_text().lower()
    assert source.count("common /com/c") == 2
    assert "b = b+e" in source and "if (f.gt.0.0)" in source
    return {"status": "pass", "explicit_common_state": {"z": z_after, "t": t_after}, "boundary": "COMMON global mutable state", "undefined_inputs": ["e", "f", "u"]}


def lh118() -> dict[str, object]:
    a = [0.0] * 101
    b = [1.0] * 101
    for i in range(5, 96):
        if a[i] > 0.0:
            a[i] = a[i] * b[i]
            if b[i] > 0.0:
                b[i] += 1.0
            else:
                b[i] += 2.0
        b[i + 1] = (b[i] + b[i + 2]) / 2.0
    # Model the defined arithmetic after an explicit in-memory READ replacement.
    b[10] = 4.0
    b[10] = b[10] * a[10]
    a[10] = a[10] * b[10]
    assert b[10] == 0.0 and a[10] == 0.0
    source = (Path(__file__).parents[2] / "upstream/tapenade/nonRegressions/set01/lh118/program.f").read_text().lower()
    assert "read *, b" in source and "call toto(a,b)" in source
    return {"status": "pass", "in_memory_loop": {"a10": a[10], "b10": b[10]}, "boundary": "active READ plus unresolved external TOTO"}


ORACLES = {"lh114-dead-loop": lh114, "lh115-call-actual": lh115, "lh117-common-state": lh117, "lh118-active-io": lh118}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = {args.case: ORACLES[args.case]()} if args.case else {name: fn() for name, fn in ORACLES.items()}
    print(json.dumps(selected, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
