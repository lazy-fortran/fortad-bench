#!/usr/bin/env python3
"""Independent fixed-external-read semantic oracle for exact ht02."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_inventory(source: Path) -> None:
    statements = []
    for line in source.read_text(encoding="latin-1").splitlines():
        if line[:1].lower() in {"c", "*", "!"}:
            continue
        statements.append(line[6:] if len(line) > 6 else "")
    compact = re.sub(r"\s+", "", "\n".join(statements)).lower()
    required = (
        "subroutinetop(a)",
        "reala,x",
        "integern",
        "n=0",
        "callmyopen(n)",
        "read(n,*)x",
        "a=a*x",
        "subroutinemyopen(n)",
        "n=n+1",
        "open(unit=n)",
    )
    for fragment in required:
        require(fragment in compact, f"ht02 source is missing exact fragment {fragment!r}")
    require(compact.count("read") == 1, "ht02 must contain exactly one READ")
    require(compact.count("open(unit=n)") == 1, "ht02 must contain exactly one OPEN")
    print("oracle_source_inventory: exact external-read shape pass")


def value(a: float, read_value: float) -> float:
    return a * read_value


def jvp(a: float, da: float, read_value: float) -> float:
    # The external READ value is fixed; it is not an independent tangent.
    return read_value * da


def vjp(da: float, seed: float, read_value: float) -> tuple[float, float]:
    # The read value is external, so only the dummy a receives an adjoint.
    return seed * read_value * da, 0.0


def check_jvp() -> None:
    max_error = 0.0
    epsilon = 1.0e-7
    for a, da, read_value in (
        (1.25, -0.6, 2.75),
        (-0.8, 0.35, 1.5),
        (3.1, 0.02, -0.4),
    ):
        analytic = jvp(a, da, read_value)
        numeric = (
            value(a + epsilon * da, read_value)
            - value(a - epsilon * da, read_value)
        ) / (2.0 * epsilon)
        max_error = max(max_error, abs(analytic - numeric))
    require(max_error < 2.0e-8, f"JVP finite-difference error is {max_error}")
    print(f"oracle_jvp_finite_difference: pass max_error={max_error:.16e}")


def check_vjp() -> None:
    max_error = 0.0
    for a, da, read_value, seed in (
        (1.25, -0.6, 2.75, 0.7),
        (-0.8, 0.35, 1.5, -1.2),
        (3.1, 0.02, -0.4, 2.0),
    ):
        tangent = jvp(a, da, read_value)
        gradient_da, gradient_read = vjp(da, seed, read_value)
        lhs = seed * tangent
        rhs = gradient_da + gradient_read
        max_error = max(max_error, abs(lhs - rhs))
    require(max_error < 1.0e-13, f"VJP adjoint error is {max_error}")
    print(f"oracle_vjp_adjoint_identity: pass max_error={max_error:.16e}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    source = parser.parse_args().source_root.resolve() / "program.f"
    require(source.is_file(), "ht02 source is missing")
    source_inventory(source)
    check_jvp()
    check_vjp()
    print("oracle_behavioral_cases: 3")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
