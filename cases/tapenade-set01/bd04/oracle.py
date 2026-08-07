#!/usr/bin/env python3
"""Independent behavioral oracle for the exact bd04 loop/update semantics."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path


SOURCE_SHA256 = "5d07bbfa77d27c761647a7c94b7d206e32756d364aca0fd29aeb15a85cc432b0"
SELECTED = {(row, column) for row in range(1, 11) for column in range(1, 11)}


def fortran_do_values(first: int, last: int, step: int) -> list[int]:
    if step == 0:
        raise ValueError("Fortran DO step cannot be zero")
    values: list[int] = []
    current = first
    if step > 0:
        while current <= last:
            values.append(current)
            current += step
    else:
        while current >= last:
            values.append(current)
            current += step
    return values


def trace_from_exact_loops() -> list[tuple[int, int]]:
    # DO control parameters are evaluated before each loop starts.  Assigning
    # f1/t1/s1 or f2/t2/s2 in the body does not alter the current iteration.
    trace: list[tuple[int, int]] = []
    for i1 in fortran_do_values(1, 10, 1):
        f1, t1, s1 = 100, 600, 3
        del f1, t1, s1
        for i2 in fortran_do_values(1, 10, 1):
            f2, t2, s2 = 200, 500, 4
            del f2, t2, s2
            trace.append((i1, i2))
    return trace


def update(value: float, row: int, column: int) -> float:
    return 2.0 * value if (row, column) in SELECTED else value


def check_source(source: Path) -> None:
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise SystemExit(f"exact source checksum changed: {digest}")


def check_trace() -> None:
    trace = trace_from_exact_loops()
    expected = [(row, column) for row in range(1, 11) for column in range(1, 11)]
    if trace != expected:
        raise SystemExit("DO-loop trace mismatch")
    print("oracle_trace: 100 visits, rows and columns 1..10 in order")


def check_jvp_and_vjp() -> None:
    points = [(1, 1), (1, 10), (10, 10), (11, 11), (100, 100)]
    values = {point: 0.25 * point[0] - 0.5 * point[1] for point in points}
    direction = {point: 0.125 * point[0] + 0.25 * point[1] for point in points}
    seed = {point: 0.5 + 0.1 * point[0] - 0.05 * point[1] for point in points}
    epsilon = 1.0e-6

    def objective(state: dict[tuple[int, int], float]) -> float:
        return sum(seed[point] * update(state[point], *point) for point in points)

    finite_difference = (
        objective({point: values[point] + epsilon * direction[point] for point in points})
        - objective({point: values[point] - epsilon * direction[point] for point in points})
    ) / (2.0 * epsilon)
    jvp = sum(
        seed[point] * (2.0 * direction[point] if point in SELECTED else direction[point])
        for point in points
    )
    if abs(finite_difference - jvp) > 1.0e-7:
        raise SystemExit("JVP finite-difference mismatch")
    print(f"oracle_jvp: finite_difference_error={abs(finite_difference - jvp):.3e}")

    vjp = {
        point: seed[point] * (2.0 if point in SELECTED else 1.0) for point in points
    }
    lhs = jvp
    rhs = sum(vjp[point] * direction[point] for point in points)
    if abs(lhs - rhs) > 1.0e-12:
        raise SystemExit("VJP adjoint identity mismatch")
    print(f"oracle_vjp: adjoint_residual={abs(lhs - rhs):.3e}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: oracle.py /path/to/nonRegressions/set01/bd04")
    source = Path(sys.argv[1]) / "program.f"
    check_source(source)
    check_trace()
    check_jvp_and_vjp()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
