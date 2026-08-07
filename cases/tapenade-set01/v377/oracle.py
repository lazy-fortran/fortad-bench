#!/usr/bin/env python3
"""Independent communication-safety oracle for Tapenade v377.

This models only the MPI rank and matching obligations visible in the source;
it does not use a compiler, Tapenade, or FortAD output.
"""

from __future__ import annotations


def main_active_ranks(world_size: int) -> set[int]:
    # The source calls TEST only in these two branches, for every world with
    # at least three processes.
    return {rank for rank in (0, 1) if rank < world_size}


def test_edges(rank: int) -> tuple[int, int]:
    # TEST receives from rank-1 and sends to rank+1 for each of its three
    # elements.
    return rank - 1, rank + 1


def main() -> None:
    world_size = 3
    active = main_active_ranks(world_size)
    assert active == {0, 1}

    source0, destination0 = test_edges(0)
    source1, destination1 = test_edges(1)
    assert source0 == -1
    assert not 0 <= source0 < world_size
    assert destination1 == 2
    assert destination1 not in active
    assert source1 == 0
    assert destination0 == 1

    print(
        "oracle_status: pass "
        "rank0-receives-from-invalid-minus-one "
        "rank1-sends-to-inactive-rank-two"
    )


if __name__ == "__main__":
    main()
