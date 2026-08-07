#!/usr/bin/env python3
"""Independent semantic oracle for the incomplete v503 SYSTEME source.

This deliberately does not invoke a compiler, Tapenade, or FortAD.  It checks
the source statement order and evaluates an abstract control-flow prefix;
there is no numerical output to model because the upstream program has no
declarations or initial state for its active variables.
"""

from __future__ import annotations

import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v503" / "program.f90"


def line_number(source: str, pattern: str) -> int:
    match = re.search(pattern, source, flags=re.IGNORECASE | re.MULTILINE)
    if match is None:
        raise AssertionError(f"missing source pattern: {pattern}")
    return source.count("\n", 0, match.start()) + 1


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    lines = source.splitlines()
    normalized = source.lower()

    assert re.search(r"^\s*program\s+systeme\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(r"^\s*end\s+program\s+systeme\s*$", source, re.IGNORECASE | re.MULTILINE)
    erreur_line = line_number(source, r"^[ \t]*erreurnumero[ \t]*=[ \t]*0[ \t]*$")
    retour_line = line_number(source, r"^[ \t]*retour[ \t]*=[ \t]*0[ \t]*$")
    first_allocate = line_number(
        source, r"^[ \t]*allocate[ \t]*\([ \t]*svrai[ \t]*\("
    )
    assert erreur_line < retour_line < first_allocate
    assert first_allocate == 80

    allocation_sites = re.findall(r"^\s*allocate\s*\(", source, flags=re.IGNORECASE | re.MULTILINE)
    assert len(allocation_sites) == 14, len(allocation_sites)
    assert "do while( erreurnumero == 0 )" in normalized
    assert "phasesimulation = phase_calcul" in normalized
    assert "phasesimulation = phase_terminaison" not in normalized
    assert "phasecouplage = phase_arret" in normalized

    # Abstractly execute the only prefix whose guards are initialized here.
    erreur_numero = 0
    retour = 0
    if erreur_numero != 0:
        first_event = "stop before allocation"
    elif retour != 0:
        first_event = "stop before allocation"
    else:
        first_event = "allocate SVRAI(size(X))"
    assert first_event == "allocate SVRAI(size(X))"

    external_calls = re.findall(r"^\s*call\s+([a-z0-9_]+)", source, flags=re.IGNORECASE | re.MULTILINE)
    assert len(external_calls) == 14
    assert "planim" in {name.lower() for name in external_calls}
    assert "stock" in {name.lower() for name in external_calls}

    # The only explicit outer-loop state transition is to CALCUL; termination
    # is a case label, not an assignment available in this source fragment.
    phase_assignments = re.findall(
        r"^\s*phasesimulation\s*=\s*([a-z0-9_]+)", source,
        flags=re.IGNORECASE | re.MULTILINE,
    )
    assert [value.lower() for value in phase_assignments] == ["phase_calcul"]

    print(f"oracle_source_lines: {len(lines)}")
    print(f"oracle_initial_guard_order: erreur_numero={erreur_line} retour={retour_line} allocation={first_allocate}")
    print(f"oracle_allocation_sites: {len(allocation_sites)}")
    print(f"oracle_first_reachable_event: {first_event}")
    print(f"oracle_external_call_sites: {len(external_calls)}")
    print("oracle_control_flow: PhaseSimulation only explicitly advances to PHASE_CALCUL; no termination assignment is present")
    print("oracle_numerical_observable: undefined-incomplete-upstream")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
