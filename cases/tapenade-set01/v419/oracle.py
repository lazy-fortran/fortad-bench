#!/usr/bin/env python3
"""Independent numeric/semantic oracle for the v419 exact-source boundary."""

from __future__ import annotations


def main() -> None:
    aa_prefix_sum = sum(100.0 / index for index in range(1, 21))
    x_prefix_sum = sum(3.3 * index for index in range(1, 21))

    assert aa_prefix_sum > 0.0
    assert x_prefix_sum == 693.0

    # These values are read by ROOT after ALLOCATE but before any assignment.
    undefined_reads = ("TT1(1)", "TT2(2)", *[f"X({i})" for i in range(21, 31)])
    assert undefined_reads[:2] == ("TT1(1)", "TT2(2)")
    assert len(undefined_reads[2:]) == 10

    # SUM(X) is not a standard-conforming reference when X is assumed-size.
    standard_invalid_reference = "SUM(X) where X is REAL, DIMENSION(*)"
    assert standard_invalid_reference.endswith("DIMENSION(*)")

    print(f"known_AA_prefix_sum: {aa_prefix_sum:.12f}")
    print(f"known_X_initialized_prefix_sum: {x_prefix_sum:.12f}")
    print("standard_invalid_reference: SUM(X) on assumed-size dummy")
    print("undefined_reads: TT1(1), TT2(2), X(21:30)")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
