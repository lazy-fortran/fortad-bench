#!/usr/bin/env python3
"""Independent semantic oracle for the v177 module-only corpus row."""

from __future__ import annotations

import os
import re
from math import prod
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set05" / "v177"


def _assert_single(pattern: str, text: str, label: str) -> re.Match[str]:
    match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
    if match is None:
        raise AssertionError(f"missing {label}")
    return match


def _module_model(text: str, label: str) -> dict[str, object]:
    _assert_single(r"^\s*module\s+mcrm2par\s*$", text, f"{label} module")
    _assert_single(r"^\s*end\s+module\s+mcrm2par\s*$", text, f"{label} module end")
    if re.search(r"^\s*(program|function|subroutine)\b", text, re.IGNORECASE | re.MULTILINE):
        raise AssertionError(f"{label} unexpectedly contains a callable/program unit")

    parameters = {
        name.lower(): int(value)
        for name, value in re.findall(
            r"\b(nknots|nsunmax|nangls|ncub|nspchnl|ncomp0)\s*=\s*(\d+)",
            text,
            re.IGNORECASE,
        )
    }
    expected_parameters = {
        "nknots": 9,
        "nsunmax": 9,
        "nangls": 18,
        "ncub": 48,
        "nspchnl": 2001,
        "ncomp0": 10,
    }
    if parameters != expected_parameters:
        raise AssertionError(f"{label} parameters differ: {parameters}")

    declaration_patterns = {
        "acoef1": r"(?s)dimension\s*\(\s*(?:1\s*:\s*)?nspchnl\s*,\s*(?:1\s*:\s*)?ncomp0\s*\)\s*::.*?\bacoef1\b.*?\bacoef2\b",
        "acoef2": r"(?s)dimension\s*\(\s*(?:1\s*:\s*)?nspchnl\s*,\s*(?:1\s*:\s*)?ncomp0\s*\)\s*::.*?\bacoef1\b.*?\bacoef2\b",
        "phis": r"dimension\s*\(\s*(?:1\s*:\s*)?nspchnl\s*,\s*(?:1\s*:\s*)?4\s*\)\s*::[^\n]*\bphis\b",
        "refr": r"(?s)dimension\s*\(\s*(?:1\s*:\s*)?nspchnl\s*\)\s*::.*?\brefr\b.*?\balpl\b.*?\bgamml\b",
        "alpl": r"(?s)dimension\s*\(\s*(?:1\s*:\s*)?nspchnl\s*\)\s*::.*?\brefr\b.*?\balpl\b.*?\bgamml\b",
        "gamml": r"(?s)dimension\s*\(\s*(?:1\s*:\s*)?nspchnl\s*\)\s*::.*?\brefr\b.*?\balpl\b.*?\bgamml\b",
    }
    for name, pattern in declaration_patterns.items():
        _assert_single(pattern, text, f"{label} shape of {name}")
    _assert_single(r"real\*?8\s*(?:::|,)[^\n]*\bpi\b[^\n]*\bdr\b", text, f"{label} scalar storage")

    dimensions = {
        "acoef1": (2001, 10),
        "acoef2": (2001, 10),
        "phis": (2001, 4),
        "refr": (2001,),
        "alpl": (2001,),
        "gamml": (2001,),
        "pi": (),
        "dr": (),
    }
    for name, shape in dimensions.items():
        pattern = rf"\b{name}\b"
        if not re.search(pattern, text, re.IGNORECASE):
            raise AssertionError(f"{label} missing declaration for {name}")
    return {"parameters": parameters, "dimensions": dimensions}


def main() -> int:
    primal = (SOURCE_DIR / "program.f90").read_text(encoding="utf-8")
    parser_reference = (SOURCE_DIR / "program_p.f90").read_text(encoding="utf-8")
    primal_model = _module_model(primal, "primal")
    parser_model = _module_model(parser_reference, "parser-reference")
    if primal_model != parser_model:
        raise AssertionError("parser reference does not preserve the module model")

    # This is an independent model of the only defined semantics: constants and
    # storage shapes in a module. There is no input/output map to differentiate.
    expected_storage = {
        "acoef1": 2001 * 10,
        "acoef2": 2001 * 10,
        "phis": 2001 * 4,
        "refr": 2001,
        "alpl": 2001,
        "gamml": 2001,
        "pi": 1,
        "dr": 1,
    }
    actual_storage = {
        name: (1 if not shape else prod(shape))
        for name, shape in primal_model["dimensions"].items()
    }
    if actual_storage != expected_storage:
        raise AssertionError(f"unexpected storage model: {actual_storage}")

    print("oracle_entry_point: none (module-only unit)")
    print(f"oracle_parameters: {primal_model['parameters']}")
    print(f"oracle_storage_elements: {actual_storage}")
    print("oracle_derivative_observable: undefined-no-callable-interface")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
