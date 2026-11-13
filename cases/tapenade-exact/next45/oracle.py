"""Independent bounded behavior/refusal models for next45."""

from __future__ import annotations

import argparse
import json
import math
from collections.abc import Callable


def _finite_difference(function: Callable[[float], float], value: float, direction: float) -> float:
    step = 1.0e-6
    return (function(value + step * direction) - function(value - step * direction)) / (2.0 * step)


def _close(left: float, right: float) -> None:
    assert math.isclose(left, right, rel_tol=4.0e-5, abs_tol=4.0e-5), (left, right)


def _scalar_contract(
    function: Callable[[float], float], value: float, direction: float, weight: float,
    boundary: str, source_boundary: str,
    derivative: float,
) -> dict[str, object]:
    primal = function(value)
    finite = _finite_difference(function, value, direction)
    jvp = derivative * direction
    vjp = derivative * weight
    _close(jvp, finite)
    _close(weight * jvp, direction * vjp)
    return {
        "status": "pass",
        "primal": {"input": value, "output": primal},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": finite,
            "vjp": vjp,
            "adjoint_left": weight * jvp,
            "adjoint_right": direction * vjp,
        },
        "refusal": {"status": "expected", "boundary": boundary},
        "source_boundary": source_boundary,
    }


def _cm01() -> dict[str, object]:
    # On the defined v4=1 branch, p2 aliases p1/v3 and the assignment p2=v4
    # writes v4 into that target before r=2*p2 is evaluated.
    return _scalar_contract(
        lambda v4: 2.0 * v4,
        1.0,
        0.23,
        1.7,
        "FortAD refuses conditional p1/p2 pointer storage identity",
        "the model keeps only the defined v4=1 branch and exposes the alias write as r=2*v4",
        2.0,
    )


def _cm02() -> dict[str, object]:
    # The scalar payload is copied into the target reached after b=>a. The
    # pointer cleanup is retained as a source boundary, not silently repaired.
    return _scalar_contract(
        lambda payload: payload,
        5.0,
        -0.31,
        1.3,
        "FortAD refuses allocate/reassociate/deallocate pointer storage identity",
        "the model checks c=5 before the exact source's alias cleanup boundary",
        1.0,
    )


def _cm03() -> dict[str, object]:
    # v2 is assigned the constant 1.0, so the v2=1 branch is deterministic:
    # p4 aliases p1/v2, p4=4, and r=2*p4+p1=12.
    return _scalar_contract(
        lambda unused: 12.0,
        0.4,
        0.17,
        1.1,
        "FortAD refuses conditional p1/p4 pointer storage identity",
        "the model records the deterministic v2=1 branch after the source overwrites v2 with 1.0",
        0.0,
    )


def _v338() -> dict[str, object]:
    return _scalar_contract(
        lambda x: x**4,
        0.8,
        -0.21,
        1.6,
        "FortAD refuses TARGET/module-pointer storage identity",
        "the model makes the pointer sequence explicit: p=x*x, p1=>p, then p=p1*p1=x**4",
        4.0 * 0.8**3,
    )


ORACLES = {
    "cm01-pointer-branch-model": _cm01,
    "cm02-pointer-reassociation-model": _cm02,
    "cm03-pointer-conditional-model": _cm03,
    "v338-module-pointer-power-model": _v338,
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
