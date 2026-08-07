#!/usr/bin/env python3
"""Independent semantic oracle for the exact lh079 source boundary."""

from __future__ import annotations

import math
import re
import sys
from pathlib import Path


FUNCTION = re.compile(
    r"^\s*double\s+precision\s+function\s+f\s*\(([^)]*)\)", re.I
)
DECLARATION = re.compile(r"^\s*double\s+precision\s+(.*)$", re.I)


def oracle(source_path: Path) -> None:
    text = source_path.read_text(encoding="utf-8")
    code = "\n".join(line.split("!", 1)[0] for line in text.splitlines())
    match = FUNCTION.search(code)
    if not match or [part.strip().lower() for part in match.group(1).split(",")] != [
        "t", "a", "ad", "b", "bd", "x"
    ]:
        raise AssertionError("unexpected f interface")
    declarations = [line.strip().lower() for line in code.splitlines() if DECLARATION.match(line)]
    if "double precision t,x" not in declarations:
        raise AssertionError("t and x are not the declared double-precision scalars")
    dimension = next((line.strip().lower() for line in code.splitlines() if line.strip().startswith("dimension ")), "")
    if dimension != "dimension a(5), b(5), ad(5), bd(5)":
        raise AssertionError("unexpected array dimensions")
    if re.search(r"^\s*(?:real|double\s+precision|integer).*\bxd\b", code, re.I | re.M):
        raise AssertionError("xd unexpectedly acquired a declaration")
    if len(re.findall(r"\bxd\b", code, re.I)) != 1:
        raise AssertionError("the unresolved xd read is not present exactly once")
    if "x**-0.5d0" not in code.lower():
        raise AssertionError("the exact negative-exponent spelling is absent")

    # Hand model of the assignments, with the unresolved xd made explicit.
    t, a1, ad1, x, xd = 1.25, 2.0, 0.75, 4.0, -0.5
    f = math.exp(t * t)
    b2 = -0.5 * a1 * x ** -0.5
    bd2 = -0.5 * (ad1 * x ** -0.5 - a1 * 0.5 * x ** (-1.5) * xd)
    expected = (math.exp(t * t), -0.5 * a1 / math.sqrt(x), bd2)
    actual = (f, b2, bd2)
    if any(abs(left - right) > 1.0e-14 for left, right in zip(actual, expected)):
        raise AssertionError(f"arithmetic model mismatch: {actual=} {expected=}")
    if bd2 == -0.5 * (ad1 * x ** -0.5 - a1 * 0.5 * x ** (-1.5) * 0.0):
        raise AssertionError("the model did not expose xd dependence")
    print(
        "oracle_status: pass interface=f(t,a,ad,b,bd,x) "
        "unresolved_read=xd arithmetic_model=pass"
    )


if __name__ == "__main__":
    oracle(Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).with_name("program.f"))
