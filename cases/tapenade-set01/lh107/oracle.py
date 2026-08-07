#!/usr/bin/env python3
"""Independent behavioral oracle for Tapenade set01 lh107."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_inventory(source: Path) -> None:
    lines = source.read_text(encoding="latin-1").splitlines()
    body = "\n".join(line for line in lines if not line[:1].lower() in {"c", "*", "!"})
    compact = re.sub(r"\s+", "", body.lower())
    required = (
        "subroutinetest(a,b)",
        "reala,b",
        "a=max(b,10.0)",
        "b=max(a,b,3.0,b,a,b,a)",
    )
    for fragment in required:
        require(fragment in compact, f"source inventory missing {fragment!r}")
    require(compact.count("max(") == 2, "lh107 MAX expression count changed")
    require(compact.index("a=max(") < compact.index("b=max("), "assignment order changed")
    print("oracle_source_inventory: pass")


def primal(a: float, b: float) -> tuple[float, float]:
    """Independently model the exact sequential assignments."""
    a_after = max(b, 10.0)
    b_after = max(a_after, b, 3.0, b, a_after, b, a_after)
    return a_after, b_after


def check_jvp() -> None:
    da, db = 0.37, -0.22
    step = 1.0e-6
    for b0 in (4.0, 16.0):
        numeric = tuple(
            (plus - minus) / (2.0 * step)
            for plus, minus in zip(
                primal(1.25 + step * da, b0 + step * db),
                primal(1.25 - step * da, b0 - step * db),
            )
        )
        slope = 0.0 if b0 < 10.0 else 1.0
        analytic = (slope * db, slope * db)
        require(
            all(math.isclose(x, y, rel_tol=2.0e-9, abs_tol=2.0e-10) for x, y in zip(numeric, analytic)),
            f"JVP finite difference mismatch at b={b0}: {numeric} != {analytic}",
        )
    print("oracle_jvp_finite_difference: pass")


def check_vjp() -> None:
    b0 = 16.0
    da, db = 0.37, -0.22
    output_seed_a, output_seed_b = 0.8, -1.3
    step = 1.0e-6
    plus = primal(1.25 + step * da, b0 + step * db)
    minus = primal(1.25 - step * da, b0 - step * db)
    output_direction = tuple((x - y) / (2.0 * step) for x, y in zip(plus, minus))
    lhs = output_seed_a * output_direction[0] + output_seed_b * output_direction[1]
    gradient_a, gradient_b = 0.0, output_seed_a + output_seed_b
    rhs = gradient_a * da + gradient_b * db
    require(math.isclose(lhs, rhs, rel_tol=0.0, abs_tol=1.0e-9), "VJP dot-product identity failed")
    print("oracle_vjp_adjoint_identity: pass")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    source = parser.parse_args().source_root.resolve() / "program.f"
    source_inventory(source)
    check_jvp()
    check_vjp()
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
