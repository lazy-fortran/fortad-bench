#!/usr/bin/env python3
"""Independent semantic oracle for the v413 undefined-local boundary."""

from __future__ import annotations


class Undefined:
    """A value whose use cannot produce a defined numerical result."""


UNDEFINED = Undefined()


def divide(numerator: float, denominator: object) -> object:
    if denominator is UNDEFINED:
        return UNDEFINED
    return numerator / denominator


def power(base: float, exponent: object) -> object:
    if exponent is UNDEFINED:
        return UNDEFINED
    return base**exponent


def f4_model(hr: float) -> tuple[object, object]:
    # This is the source's statement order.  mt has no defining assignment.
    mt = UNDEFINED
    exponent = divide(1.0, mt)
    ss = power(hr, exponent)
    f4 = ss
    return ss, f4


def main() -> None:
    ss, f4 = f4_model(2.0)
    assert ss is UNDEFINED
    assert f4 is UNDEFINED
    print(
        "oracle_status: pass undefined-mt-propagates-through-exponent-ss-and-f4"
    )


if __name__ == "__main__":
    main()
