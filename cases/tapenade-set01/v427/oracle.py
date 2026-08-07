"""Independent allocation-state oracle for the exact v427 procedure."""

from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import re


SOURCE = Path(
    os.environ.get(
        "TAPENADE_REPO", "/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"
    )
) / "todoF90" / "REFERENCES" / "v427" / "program.f90"


@dataclass
class AllocationState:
    some_t_data_extent: int | None = None
    i_extent: int | None = None


class AllocationFailure(RuntimeError):
    pass


def setup_data(state: AllocationState, dim: int) -> None:
    """Model the standard allocation effects without running Fortran."""
    if dim < 0:
        raise AllocationFailure("negative extent")
    if state.some_t_data_extent is not None:
        state.some_t_data_extent = None
    state.some_t_data_extent = dim
    if state.i_extent is not None:
        raise AllocationFailure("i is already allocated")
    state.i_extent = dim


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert re.search(r"(?im)^\s*real\s*,\s*dimension\s*\(:\)\s*,\s*allocatable\s*::\s*sometdata", source)
    assert re.search(r"(?im)^\s*integer\s*,\s*dimension\s*\(:\)\s*,\s*allocatable\s*::\s*i", source)
    assert len(re.findall(r"(?im)^\s*allocate\s*\(", source)) == 2
    assert not re.search(r"(?im)^\s*(?:sometdata|i)\s*=", source)

    state = AllocationState()
    setup_data(state, 3)
    assert state == AllocationState(some_t_data_extent=3, i_extent=3)

    try:
        setup_data(state, 5)
    except AllocationFailure as error:
        assert str(error) == "i is already allocated"
    else:
        raise AssertionError("second setupData call unexpectedly succeeded")
    assert state == AllocationState(some_t_data_extent=5, i_extent=3)

    print("first_call_extent: someTData=3 i=3")
    print("second_call_effect: someTData=5 then allocation_failure=i_already_allocated")
    print("numeric_contents: undefined (setupData assigns no array elements)")
    print("oracle_status: pass")
    print("oracle_result: allocation-state boundary; no numerical derivative map")


if __name__ == "__main__":
    main()
