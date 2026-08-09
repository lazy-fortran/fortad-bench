#!/usr/bin/env python3
"""Independent behavioral and refusal models for next36.

The models do not read Tapenade output, FortAD output, or the committed
ledger.  They check the bounded generic-elemental maps and the defined
colored-edge primal behavior independently of the transformation probes.
"""

from __future__ import annotations

import argparse
import json
import math


def _finite_difference(function, value: float, direction: float) -> float:
    step = 1.0e-6
    return (function(value + step * direction) - function(value - step * direction)) / (2.0 * step)


def _generic_elemental(name: str, real_map, expected_real: float, expected_test: float) -> dict[str, object]:
    x = 1.25
    i = 3
    direction = 0.37
    cotangent = 1.7

    def test(value: float, integer: int) -> float:
        return real_map(value) + 2.0 * integer

    hand = 2.0 * direction
    finite = _finite_difference(lambda value: test(value, i), x, direction)
    vjp = 2.0 * cotangent
    assert 2 * i == 6
    assert math.isclose(real_map(x), expected_real, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(test(x, i), expected_test, rel_tol=0.0, abs_tol=1.0e-12)
    assert math.isclose(hand, finite, rel_tol=0.0, abs_tol=2.0e-9)
    assert math.isclose(hand * cotangent, direction * vjp, rel_tol=0.0, abs_tol=1.0e-12)
    return {
        "status": "pass",
        "primal": {
            "model": name,
            "real_dispatch": real_map(x),
            "integer_dispatch": 2 * i,
            "test": test(x, i),
        },
        "derivative": {
            "status": "checked-independent",
            "jvp": hand,
            "finite_difference_jvp": finite,
            "vjp": [vjp],
            "adjoint_left": hand * cotangent,
            "adjoint_right": direction * vjp,
        },
        "refusal": {"status": "not-applicable", "boundary": "none observed"},
    }


def _v311() -> dict[str, object]:
    return _generic_elemental(
        "twice_real(x) = 2*(x+3), twice_int(i) = 2*i",
        lambda value: 2.0 * (value + 3.0),
        expected_real=8.5,
        expected_test=14.5,
    )


def _v357() -> dict[str, object]:
    return _generic_elemental(
        "twice_real(x) = 2*x, twice_int(i) = 2*i",
        lambda value: 2.0 * value,
        expected_real=2.5,
        expected_test=8.5,
    )


def _vmp09() -> dict[str, object]:
    return _generic_elemental(
        "twice_real(x) = 2*x, twice_int(i) = 2*i",
        lambda value: 2.0 * value,
        expected_real=2.5,
        expected_test=8.5,
    )


def _tinymgopt() -> dict[str, object]:
    """Model createAndRun for a safe six-node, two-iteration mesh."""
    num_nodes = 6
    num_edges = num_nodes - 1
    num_iters = 2
    dv = [0.5] * num_nodes
    sij = [0.5] * num_edges
    edges: list[tuple[int, int]] = []
    for edge in range(1, num_edges // 2 + 2):
        edges.append((edge * 2 - 1, edge * 2))
    for edge in range(1, num_edges // 2 + 1):
        edges.append((edge * 2, edge * 2 + 1))
    assert len(edges) == num_edges
    gradient = [0.0] * num_nodes
    for _ in range(num_iters):
        for index, (left, right) in enumerate(edges):
            assert left != right
            face = 0.5 * (dv[left - 1] + dv[right - 1])
            gradient[left - 1] += face * sij[index]
            gradient[right - 1] -= face * sij[index]
    assert gradient == [0.5, 0.0, 0.0, 0.0, 0.0, -0.5]
    total = sum(gradient)
    assert math.isclose(total, 0.0, rel_tol=0.0, abs_tol=1.0e-12)
    return {
        "status": "pass",
        "primal": {
            "model": "six-node colored-edge mesh with two createAndRun iterations",
            "edges": edges,
            "gradient": gradient,
            "sum_gradient": total,
        },
        "refusal": {
            "status": "expected",
            "boundary": "active WRITE of SUM(GRADIENT), source line 51; OpenMP directive is later",
        },
        "derivative_claim": "none for the exact I/O-containing root",
    }


ORACLES = {
    "v311-generic-elemental": _v311,
    "v357-generic-elemental": _v357,
    "vmp09-generic-elemental": _vmp09,
    "tinymgopt-colored-edge": _tinymgopt,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(ORACLES))
    args = parser.parse_args()
    selected = [args.case] if args.case else sorted(ORACLES)
    values = {name: ORACLES[name]() for name in selected}
    print(json.dumps(values, indent=2, sort_keys=True))
    return 0 if all(value["status"] == "pass" for value in values.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
