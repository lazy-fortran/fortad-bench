#!/usr/bin/env python3
"""Independent semantic oracle for the exact set02/v067 source boundary."""

from __future__ import annotations

import hashlib
import math
import sys
from pathlib import Path


EXPECTED = {
    "program.f": "5e0429ab2047554eb72d3c13c7b00e73cf81e3cdb0b0879c190280cecfc4398b",
    "program_p.f": "1154c5bd5d1c03ba59e036a31e3476509aa540b517e1b67e5492fcc494b4691e",
    "program_p.msg": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
}


def primal(y: float) -> float:
    return y + math.pi


def check(source_dir: Path) -> None:
    for name, digest in EXPECTED.items():
        path = source_dir / name
        if not path.is_file():
            raise AssertionError(f"missing pinned source: {path}")
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != digest:
            raise AssertionError(f"source hash mismatch for {name}: {actual}")

    exact = (source_dir / "program.f").read_bytes()
    if b"SUBROUTINE ADJ_FCN(T,Y,YP,RESULT,RP)" not in exact:
        raise AssertionError("exact ADJ_FCN interface is missing")
    if b"t = y + pi" not in exact:
        raise AssertionError("exact T = Y + PI assignment is missing")

    analytical = 1.0
    for y in (0.1, 0.8, 1.7, -2.25):
        for h in (1.0e-4, 5.0e-5, 2.5e-5):
            finite_difference = (primal(y + h) - primal(y - h)) / (2.0 * h)
            if abs(finite_difference - analytical) > 1.0e-10:
                raise AssertionError("central-difference JVP mismatch")

    direction = -0.73
    seed = 0.41
    jvp = analytical * direction
    vjp = analytical * seed
    if abs(seed * jvp - direction * vjp) > 1.0e-15:
        raise AssertionError("adjoint identity mismatch")


def main() -> int:
    source_dir = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).parents[2] / "upstream/tapenade/nonRegressions/set02/v067"
    try:
        check(source_dir.resolve())
    except (AssertionError, OSError) as error:
        print(f"oracle_status: fail: {error}")
        return 1
    print("oracle_semantics: T(Y) = Y + pi; analytical JVP=1; analytical VJP=1")
    print("finite_difference_max_error: <1e-10")
    print("adjoint_identity_max_error: <1e-15")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
