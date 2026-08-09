"""Independent bounded behavior/refusal models for next46."""

from __future__ import annotations

import argparse
import json
import math
from collections.abc import Callable


def _close(left: float, right: float) -> None:
    assert math.isclose(left, right, rel_tol=4.0e-5, abs_tol=4.0e-5), (left, right)


def _finite_difference(function: Callable[[float], float], value: float) -> float:
    step = 1.0e-6
    return (function(value + step) - function(value - step)) / (2.0 * step)


def _interval_contract(
    function: Callable[[float, float], tuple[float, float]],
    derivative: tuple[float, float],
    state_boundary: str,
    source_boundary: str,
) -> dict[str, object]:
    lower = 0.8
    upper = -1.1
    direction = (0.27, -0.19)
    weight = (1.4, -0.8)
    primal = function(lower, upper)
    finite_lower = _finite_difference(lambda value: function(value, upper)[0], lower)
    finite_upper = _finite_difference(lambda value: function(lower, value)[1], upper)
    _close(finite_lower, derivative[0])
    _close(finite_upper, derivative[1])
    jvp = derivative[0] * direction[0] + derivative[1] * direction[1]
    vjp = (derivative[0] * weight[0], derivative[1] * weight[1])
    _close(weight[0] * derivative[0] * direction[0] + weight[1] * derivative[1] * direction[1],
           direction[0] * vjp[0] + direction[1] * vjp[1])
    return {
        "status": "pass",
        "primal": {"lower": primal[0], "upper": primal[1]},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_components": [finite_lower, finite_upper],
            "vjp": {"lower": vjp[0], "upper": vjp[1]},
        },
        "refusal": {"status": "expected", "boundary": state_boundary},
        "source_boundary": source_boundary,
    }


def _v036() -> dict[str, object]:
    x_lower = 1.5
    y_upper = -0.25
    return _interval_contract(
        lambda lower, upper: (2.0 * lower + x_lower, 2.0 * upper + y_upper),
        (2.0, 2.0),
        "FortAD refuses module-level mutable interval state x",
        "the model holds x.lower and y.upper fixed while differentiating t",
    )


def _v274() -> dict[str, object]:
    # The exact source calls implicit external f_cb with no local definition.
    # Check the defined lower component without inventing a runtime contract for
    # that unresolved call.
    x_lower = 1.5
    lower = 0.8
    direction = 0.27
    finite = _finite_difference(lambda value: 2.0 * value + x_lower, lower)
    _close(finite, 2.0)
    return {
        "status": "pass",
        "primal": {"defined_lower_component": 2.0 * lower + x_lower},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": 2.0 * direction,
            "finite_difference_jvp": finite * direction,
        },
        "refusal": {
            "status": "expected",
            "boundary": "FortAD refuses module-level mutable x before implicit external f_cb",
        },
        "source_boundary": "f_cb has no definition in the exact upstream case; no exact runtime or derivative claim",
    }


def _v275() -> dict[str, object]:
    x_lower = 1.5
    y_upper = -0.25
    return _interval_contract(
        lambda lower, upper: (
            2.0 * lower + x_lower,
            2.0 * upper + y_upper + upper * upper,
        ),
        (2.0, 2.0 + 2.0 * -1.1),
        "FortAD refuses module-level mutable interval state x",
        "the model keeps x.lower and y.upper fixed and includes the local f_cd(t.upper)=t.upper**2 term",
    )


def _cm17() -> dict[str, object]:
    # For v2>4 the exact source associates p1 with v3, then writes 5 through
    # that alias. Other branches can leave p1 unassociated and are excluded.
    v2 = 5.0
    v3 = 1.25
    output = {"p1_target": "v3", "v2": v2, "v3": 5.0}
    function = lambda value: 5.0 if value > 4.0 else math.nan
    finite = _finite_difference(function, v2)
    _close(finite, 0.0)
    return {
        "status": "pass",
        "primal": output,
        "derivative": {
            "status": "checked-independent-model-only",
            "branch": "v2>4",
            "jvp": 0.0,
            "finite_difference_jvp": finite,
        },
        "refusal": {
            "status": "expected",
            "boundary": "FortAD refuses p1 pointer-association storage identity",
        },
        "source_boundary": "unassociated v2 branches are intentionally outside this bounded model",
    }


ORACLES = {
    "v036-interval-state-model": _v036,
    "v274-interval-external-boundary": _v274,
    "v275-interval-quadratic-state-model": _v275,
    "cm17-defined-pointer-branch": _cm17,
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
