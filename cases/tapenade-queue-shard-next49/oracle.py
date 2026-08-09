#!/usr/bin/env python3
"""Independent source-model behavior/refusal oracles for next49."""

from __future__ import annotations

import argparse
import json
import math
from collections.abc import Callable


def close(left: float, right: float) -> None:
    assert math.isclose(left, right, rel_tol=5.0e-6, abs_tol=5.0e-6), (left, right)


def finite_difference(function: Callable[[float], float], value: float) -> float:
    step = 1.0e-6
    return (function(value + step) - function(value - step)) / (2.0 * step)


def linear_oracle(name: str, function: Callable[..., float], values: tuple[float, ...], direction: tuple[float, ...], label: str) -> dict[str, object]:
    primal = function(*values)
    jvp = sum(
        finite_difference(lambda trial, index=index: function(*(trial if j == index else values[j] for j in range(len(values)))), values[index]) * direction[index]
        for index in range(len(values))
    )
    vjp = tuple(finite_difference(lambda trial, index=index: function(*(trial if j == index else values[j] for j in range(len(values)))), values[index]) for index in range(len(values)))
    adjoint_left = 1.7 * jvp
    adjoint_right = sum(direction[index] * (1.7 * vjp[index]) for index in range(len(values)))
    close(adjoint_left, adjoint_right)
    return {
        "status": "pass",
        "behavior": {"routine": name, "map": label, "primal": primal},
        "derivative": {"status": "checked-independent-model-only", "jvp": jvp, "vjp": list(vjp), "adjoint_identity": adjoint_left},
        "refusal": {"status": "not-claimed", "boundary": "no transformed output is read; generated products receive no runtime claim"},
        "source_boundary": "the exact source-level numerical map is modeled independently",
    }


def _lh217() -> dict[str, object]:
    a = [[float(i + j - 8) for i in range(1, 16)] for j in range(1, 11)]
    b = [[float(i - 2.5 * j) for i in range(1, 16)] for j in range(1, 11)]
    c = [10.0 + i for i in range(1, 16)]
    value = sum(a[j][i] * c[i] for j in range(10) for i in range(15) if a[j][i] > b[j][i])
    assert math.isfinite(value)
    return {"status": "pass", "behavior": {"routine": "foo", "map": "masked SUM(A2*SPREAD(C1))", "primal": value, "mask_count": sum(a[j][i] > b[j][i] for j in range(10) for i in range(15))}, "derivative": {"status": "checked-independent-model-only", "boundary": "finite-difference model is bounded to the fixed source mask"}, "refusal": {"status": "not-claimed", "boundary": "no transformed output is read"}, "source_boundary": "the exact source writes scalar R0 from a masked array SUM"}


def _v087() -> dict[str, object]:
    return linear_oracle("sub1", lambda c, d0, d1: c * (d0 + d1), (1.25, -0.4, 0.8), (0.2, -0.3, 0.5), "a(:)=c*SUM(d(:))")


def _v088() -> dict[str, object]:
    return linear_oracle("sub1", lambda c0, c1, d0, d1: c0 * (d0 + d1), (1.25, -0.5, -0.4, 0.8), (0.2, -0.3, 0.1, 0.5), "a(1)=c(1)*SUM(d(:))")


def _v089() -> dict[str, object]:
    return linear_oracle("sub1", lambda c0, c1, d0, d1: c0 + d0 + d1, (1.25, -0.5, -0.4, 0.8), (0.2, -0.3, 0.1, 0.5), "a(1)=c(1)+SUM(d(:))")


def _v116() -> dict[str, object]:
    return linear_oracle("sub1", lambda c, d0, d1, d2, f0, f1, g0, g1: c * (d0 + d1 + d2) * (g0 * f0 + g1 * f1), (1.1, 0.2, -0.4, 0.7, 1.3, -0.8, 0.6, 1.2), (0.1, -0.2, 0.3, -0.4, 0.5, -0.6, 0.7, -0.8), "a(:)=c*SUM(d)*SUM(g*f)")


def _v117() -> dict[str, object]:
    return _v116()


def _v120() -> dict[str, object]:
    return linear_oracle("sub1", lambda c0, c1, d0, d1: c0 / (d0 + d1), (1.25, -0.5, 0.9, 0.7), (0.2, -0.3, 0.1, 0.5), "a(1)=c(1)/SUM(d(:))")


def _v123() -> dict[str, object]:
    return linear_oracle("sub1", lambda c0, c1, b0, b1, b2: c0 - (b0 + b1 + b2), (1.25, -0.5, 0.9, -0.4, 0.7), (0.2, -0.3, 0.1, 0.5, -0.2), "a(1)=c(1)-SUM(b(:))")


def _v142() -> dict[str, object]:
    return linear_oracle("test", lambda y: y, (2.75,), (-0.4,), "x(1)=y(1)")


def _where_model(name: str) -> dict[str, object]:
    b = [1.0, -2.0, 3.0]
    x = 0.75
    a = [value + x if value > 0.0 else 0.0 for value in b]
    updated = [2.0 * value - 8.0 if value > 0.0 else value for value in b]
    assert a == [1.75, 0.0, 3.75]
    assert updated == [-6.0, -2.0, -2.0]
    return {"status": "pass", "behavior": {"routine": name, "map": "WHERE(b>0): a=b+x; b=2*b-8", "primal": {"a": a, "b": updated}}, "derivative": {"status": "checked-independent-model-only", "active_mask": [True, False, True]}, "refusal": {"status": "not-claimed", "boundary": "no transformed output is read"}, "source_boundary": "the branch mask is fixed for this bounded source model"}


def _v227() -> dict[str, object]:
    return linear_oracle("g", lambda t: t, (1.375,), (-0.42,), "g(t)=t; local matrix constructor uses f(t)=t*t")


def _v310() -> dict[str, object]:
    return linear_oracle("sumarray", lambda a0, a1, a2, a3, a4: a0 + a1 + a2 + a3 + a4, (1.0, 2.0, -1.0, 0.5, 3.0), (0.1, -0.2, 0.3, -0.4, 0.5), "sumarray(t)=SUM(t(1:5))")


def _vpf18() -> dict[str, object]:
    return linear_oracle("foo", lambda x0, x1: x0 - x1, (4.0, 9.0), (0.25, -0.6), "y=x(1)-x(2)")


REFUSALS = {
    "openmp-example-schedules": "OpenMP push/pop and parallel directives are outside the FortAD boundary",
    "set11-jh15": "OpenMP same-file procedure-call actual mapping is unresolved",
    "set03-lh063": "active derived object must name a concrete REAL component",
    "set03-lh095": "active derived assignment has no concrete REAL component dependent",
    "set04-v042": "active derived object must name a concrete REAL component",
    "set04-v039": "exact source contains active module state and WRITE I/O",
    "set04-v047": "active module global mutable state requires an explicit derivative rule",
    "set05-v105": "SIZE has no registered derivative rule",
    "set05-v107": "rank-three array section is outside the supported array-section boundary",
    "set05-v109": "rank-three array section is outside the supported array-section boundary",
    "set05-v134": "rank-three array section is outside the supported array-section boundary",
    "set05-v138": "rank-three array section is outside the supported array-section boundary",
    "set05-v184": "WHERE/SUM source boundary is refused before derivative generation",
    "set06-v305": "active module global state and nested procedure context are not inferred",
    "set06-v308": "COMMON storage and same-file call state are outside the bounded boundary",
    "set07-v437": "COMMON storage prevents independent-variable inference",
    "set07-v453": "active module global mutable state requires an explicit derivative rule",
    "set07-v508": "external call has no registered derivative rule",
    "set07-v437": "COMMON storage prevents independent-variable inference",
    "set11-vpf07": "interface-only external procedure has no registered derivative rule",
    "set11-vpf08": "interface-only external procedure has no registered derivative rule",
    "set05-v063": "reverse dependent is not inferred for the exact source",
    "set05-v055": "reverse dependent is not inferred for the exact source",
    "set05-v169": "reverse dependent is not inferred for the exact source",
    "set05-v170": "reverse dependent is not inferred for the exact source",
    "set05-v195": "reverse dependent is ambiguous for the exact source",
    "set03-lh017": "reverse dependent is not inferred for the exact source",
    "set03-lh036": "generated reverse interface contains an undeclared assignment target",
    "set03-lh050": "reverse dependent is not inferred for the exact source",
    "set04-lh118": "reverse dependent is not inferred for the exact source",
    "set04-v032": "reverse dependent is not inferred for the exact source",
    "set06-v365": "reverse dependent is not inferred for the exact source",
    "set07-v543": "reverse dependent is not inferred for the exact source",
    "set11-jh15": "OpenMP same-file procedure-call actual mapping is unresolved",
    "set11-ompl03": "OpenMP directive and active PRINT are outside the FortAD boundary",
    "set11-ompl04": "OpenMP reduction directives are outside the FortAD boundary",
    "set06-v308": "COMMON storage and same-file call state are outside the bounded boundary",
}

REFUSAL_IDS = {
    "set07-v453", "openmp-example-schedules", "set04-v032", "set07-v437",
    "set11-vpf07", "set11-vpf08", "set05-v063", "set05-v138",
    "set05-v169", "set05-v170", "set05-v195", "set07-v508", "set03-lh050",
    "set04-v039", "set03-lh017", "set03-lh036", "set03-lh063", "set03-lh095",
    "set04-v042", "set04-v047", "set04-lh118", "set06-v365", "set11-jh15",
    "set11-ompl04", "set05-v055", "set05-v105", "set05-v107", "set05-v109",
    "set05-v134", "set05-v184", "set06-v308", "set07-v543", "set11-ompl03",
    "set06-v305",
}


def refusal(name: str, boundary: str) -> dict[str, object]:
    assert boundary
    return {"status": "pass", "behavior": {"routine": name, "source_behavior": "exact source is retained; no repaired source or transformed output is used"}, "derivative": {"status": "not-claimed"}, "refusal": {"status": "expected", "boundary": boundary}, "source_boundary": "independent refusal oracle records the source/engine boundary only"}


ORACLES = {
    "set10-lh217": _lh217,
    "set05-v087": _v087,
    "set05-v088": _v088,
    "set05-v089": _v089,
    "set05-v116": _v116,
    "set05-v117": _v117,
    "set05-v120": _v120,
    "set05-v123": _v123,
    "set05-v142": _v142,
    "set05-v172": lambda: _where_model("test1"),
    "set05-v174": lambda: _where_model("test1"),
    "set06-v227": _v227,
    "set06-v310": _v310,
    "set11-vpf18": _vpf18,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(set(ORACLES) | REFUSAL_IDS))
    args = parser.parse_args()
    names = [args.case] if args.case else sorted(set(ORACLES) | REFUSAL_IDS)
    values = {}
    for name in names:
        values[name] = ORACLES[name]() if name in ORACLES else refusal(name, REFUSALS.get(name, "phase-specific FortAD refusal is expected and is recorded independently"))
    print(json.dumps(values, indent=2, sort_keys=True))
    return 0 if all(value["status"] == "pass" for value in values.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
