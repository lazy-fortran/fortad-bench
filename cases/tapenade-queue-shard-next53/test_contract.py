"""Contract and independent-oracle checks for next53."""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

CASE = Path(__file__).resolve().parent
SOURCE = CASE.parents[1] / "cases/tapenade-queue-shard-next52/test_contract.py"
SPEC = importlib.util.spec_from_file_location("next52_contract", SOURCE)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)
MODULE.CASE = CASE
MODULE.ROOT = CASE.parents[1]


def test_contract() -> None:
    MODULE.test_contract()


def test_independent_oracle() -> None:
    MODULE.test_independent_oracle()


if __name__ == "__main__":
    test_contract()
    test_independent_oracle()
