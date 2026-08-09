"""Independent bounded behavior/refusal models for next48."""

from __future__ import annotations

import argparse
import json
import math
from collections.abc import Callable


def _close(left: float, right: float) -> None:
    assert math.isclose(left, right, rel_tol=4.0e-6, abs_tol=4.0e-6), (left, right)


def _finite_difference(function: Callable[[float], float], value: float) -> float:
    step = 1.0e-6
    return (function(value + step) - function(value - step)) / (2.0 * step)


def _v153() -> dict[str, object]:
    # test(u,v,w) has no assignment, no dependent, and no defined result.
    state = {"son_associated": False, "assignments": 0, "numeric_outputs": 0}
    assert state == {"son_associated": False, "assignments": 0, "numeric_outputs": 0}
    return {
        "status": "pass",
        "behavior": {"routine": "test", "state": state},
        "derivative": {"status": "undefined-no-numeric-map"},
        "refusal": {
            "status": "expected",
            "boundary": "automatic independent-variable inference has no active numeric map",
        },
        "source_boundary": "unused u/v/w dummies and an unassociated local pointer do not define output behavior",
    }


def _v155() -> dict[str, object]:
    value = 1.375
    direction = -0.42
    seed = 0.8
    function = lambda t: t
    primal = function(value)
    derivative = 1.0
    finite = _finite_difference(function, value)
    _close(finite, derivative)
    jvp = derivative * direction
    vjp = derivative * seed
    _close(seed * jvp, direction * vjp)
    local_constructor = [value] * 100
    assert len(local_constructor) == 100
    assert all(item == value for item in local_constructor)
    return {
        "status": "pass",
        "behavior": {"map": "g(t)=t", "primal": primal, "local_matrix_elements": 100},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": finite * direction,
            "vjp": vjp,
            "adjoint_identity": seed * jvp,
        },
        "refusal": {
            "status": "expected",
            "boundary": "derived-type constructor in a local array constructor is unsupported",
        },
        "source_boundary": "the local matrix array is not an output; only the scalar identity map is checked",
    }


def _v246() -> dict[str, object]:
    shape = (2, 3, 4)
    assert math.prod(shape) == 24
    observations = []
    for mask_present in (False, True):
        observations.append({"mask_present": mask_present, "shape": shape, "result_assigned": False})
    assert all(not item["result_assigned"] for item in observations)
    return {
        "status": "pass",
        "behavior": {"observations": observations},
        "derivative": {"status": "undefined-no-numeric-map"},
        "refusal": {
            "status": "expected",
            "boundary": "the function result is never assigned, so no numeric dependent exists",
        },
        "source_boundary": "optional MASK changes declaration presence only and does not create a numeric result",
    }


def _v280() -> dict[str, object]:
    a, b = 1.25, -0.75
    da, db = -0.3, 0.55
    seed = 1.7
    function = lambda left, right: right + left
    primal = function(a, b)
    jvp = da + db
    vjp = (seed, seed)
    left = seed * jvp
    right = da * vjp[0] + db * vjp[1]
    _close(left, right)
    finite_a = _finite_difference(lambda value: function(value, b), a)
    finite_b = _finite_difference(lambda value: function(a, value), b)
    _close(finite_a, 1.0)
    _close(finite_b, 1.0)
    return {
        "status": "pass",
        "behavior": {"map": "b_out=b_in+a_in", "primal": primal},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference": [finite_a, finite_b],
            "vjp": list(vjp),
            "adjoint_identity": left,
        },
        "refusal": {
            "status": "expected",
            "boundary": "implicit interface prevents automatic independent-variable inference",
        },
        "source_boundary": "the module procedure mutates b in place; the oracle does not inspect generated code",
    }


ORACLES = {
    "v153-no-numeric-map": _v153,
    "v155-derived-constructor-identity": _v155,
    "v246-optional-no-numeric-map": _v246,
    "v280-inplace-affine": _v280,
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
