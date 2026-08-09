"""Independent bounded behavior/refusal models for next44."""

from __future__ import annotations

import argparse
import json
import math
from collections.abc import Callable


def _finite_difference(function: Callable[[float], float], value: float, direction: float) -> float:
    step = 1.0e-6
    return (function(value + step * direction) - function(value - step * direction)) / (2.0 * step)


def _assert_close(left: float, right: float) -> None:
    assert math.isclose(left, right, rel_tol=4.0e-5, abs_tol=4.0e-5), (left, right)


def _mpi_message_model() -> dict[str, object]:
    value = 2.25
    direction = -0.4
    weight = 1.7
    payload = lambda x: x
    jvp = direction
    finite = _finite_difference(payload, value, direction)
    vjp = weight
    _assert_close(jvp, finite)
    _assert_close(weight * jvp, direction * vjp)
    return {
        "status": "pass",
        "primal": {"input": value, "received_payload": payload(value)},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": finite,
            "vjp": vjp,
            "adjoint_left": weight * jvp,
            "adjoint_right": direction * vjp,
        },
        "refusal": {
            "status": "expected",
            "boundary": "FortAD has no derivative rule for MPI_ISEND in the exact source",
        },
        "source_boundary": "the model treats a completed MPI send/receive payload as identity and does not model MPI runtime scheduling",
    }


def _cross_product(left: list[float], right: list[float]) -> list[float]:
    return [
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    ]


def _lh087_model() -> dict[str, object]:
    value = [0.4, -0.8, 1.25]
    direction = [0.17, 0.05, -0.12]
    fixed = [11.0, 12.0, 13.0]
    weights = [1.2, -0.7, 0.5]
    primal = _cross_product(value, fixed)
    jvp_vector = _cross_product(direction, fixed)
    objective = lambda point: sum(weight * item for weight, item in zip(weights, _cross_product(point, fixed)))
    jvp = sum(weight * item for weight, item in zip(weights, jvp_vector))
    step = 1.0e-6
    finite = (objective([item + step * delta for item, delta in zip(value, direction)]) - objective([item - step * delta for item, delta in zip(value, direction)])) / (2.0 * step)
    vjp = [
        fixed[1] * weights[2] - fixed[2] * weights[1],
        fixed[2] * weights[0] - fixed[0] * weights[2],
        fixed[0] * weights[1] - fixed[1] * weights[0],
    ]
    _assert_close(jvp, finite)
    _assert_close(jvp, sum(delta * adjoint for delta, adjoint in zip(direction, vjp)))
    return {
        "status": "pass",
        "primal": {"output": primal, "fixed_vector": fixed},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": finite,
            "vjp": vjp,
            "adjoint_left": jvp,
            "adjoint_right": sum(delta * adjoint for delta, adjoint in zip(direction, vjp)),
        },
        "refusal": {
            "status": "expected",
            "boundary": "FortAD does not yet track vector-subscript section storage identity",
        },
        "source_boundary": "the model computes the same cross product with ordinary scalar subscripts",
    }


def _html01_model() -> dict[str, object]:
    state = 1.25
    value = 0.7
    direction = -0.23
    weight = 1.7
    function = lambda z: z * z + state
    primal = function(value)
    jvp = 2.0 * value * direction
    finite = _finite_difference(function, value, direction)
    vjp = 2.0 * value * weight
    _assert_close(jvp, finite)
    _assert_close(weight * jvp, direction * vjp)
    return {
        "status": "pass",
        "primal": {"input": value, "initial_state": state, "output": primal, "updated_state": primal},
        "derivative": {
            "status": "checked-independent-model-only",
            "jvp": jvp,
            "finite_difference_jvp": finite,
            "vjp": vjp,
            "adjoint_left": weight * jvp,
            "adjoint_right": direction * vjp,
        },
        "refusal": {
            "status": "expected",
            "boundary": "FortAD parser currently rejects the exact BIND(C)/COMMON declaration",
        },
        "source_boundary": "the model makes COMMON state explicit and applies the one-call recurrence z_out=z_in**2+state",
    }


class AllocationError(RuntimeError):
    pass


def _allocate(state: dict[str, bool], *names: str) -> None:
    for name in names:
        if state[name]:
            raise AllocationError(f"{name} is already allocated")
    for name in names:
        state[name] = True


def _bd09_model() -> dict[str, object]:
    state = {"cindex": False, "dindex": False}
    events = []
    _allocate(state, "cindex")
    events.append("allocate(cindex)")
    try:
        _allocate(state, "cindex", "dindex")
    except AllocationError as error:
        events.append(f"invalid: {error}")
    else:
        raise AssertionError("the second cindex allocation must be invalid")
    assert state == {"cindex": True, "dindex": False}
    return {
        "status": "pass",
        "primal": {"events": events, "state_at_failure": state},
        "derivative": {"status": "not-applicable-invalid-upstream"},
        "refusal": {
            "status": "expected",
            "boundary": "execution attempts ALLOCATE(cindex,dindex) while cindex is already allocated",
        },
        "source_boundary": "strict syntax acceptance is not runtime validity; no repaired pointer program or derivative claim is made",
    }


ORACLES = {
    "v315-mpi-message-model": _mpi_message_model,
    "lh087-cross-product": _lh087_model,
    "html01-stateful-common-model": _html01_model,
    "bd09-invalid-pointer-sequence": _bd09_model,
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
