#!/usr/bin/env python3
"""Independent semantic oracle for the v017 no-entry-point boundary."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def declaration_inventory(source: str) -> dict[str, object]:
    lines = [line.split("!", 1)[0].rstrip() for line in source.splitlines()]
    normalized = "\n".join(lines)
    types = {}
    index = 0
    while index < len(lines):
        match = re.match(
            r"^[ \t]*type[ \t]+([a-z][a-z0-9_]*)(.*)$",
            lines[index],
            flags=re.IGNORECASE,
        )
        if match is None:
            index += 1
            continue
        name = match.group(1).lower()
        attributes = " ".join(match.group(2).lower().split())
        attribute_lines = []
        index += 1
        fields = []
        while index < len(lines) and not re.match(
            r"^[ \t]*end[ \t]+type\b", lines[index], flags=re.IGNORECASE
        ):
            field = re.match(
                r"^[ \t]*double[ \t]+precision(?:[ \t]*::[ \t]*|[ \t]+)([a-z][a-z0-9_]*)",
                lines[index],
                flags=re.IGNORECASE,
            )
            if field is not None:
                fields.append(field.group(1).lower())
            else:
                attribute = re.match(
                    r"^[ \t]*(sequence(?:[ \t]+private)?|private(?:[ \t]+sequence)?)[ \t]*$",
                    lines[index],
                    flags=re.IGNORECASE,
                )
                if attribute is not None:
                    attribute_lines.append(" ".join(attribute.group(1).lower().split()))
            index += 1
        if attribute_lines:
            attributes = " ".join(attribute_lines)
        types[name] = {"attributes": attributes, "fields": tuple(fields)}
        index += 1

    executable_units = re.findall(
        r"(?im)^[ \t]*(?:program|subroutine|function)[ \t]+[a-z][a-z0-9_]*",
        normalized,
    )
    common = re.search(
        r"(?im)^[ \t]*common[ \t]*/[ \t]*vars[ \t]*/[ \t]*ff[ \t]*,[ \t]*bval[ \t]*$",
        normalized,
    )
    return {
        "module": bool(re.search(r"(?im)^[ \t]*module[ \t]+z[ \t]*$", normalized)),
        "end_module": bool(
            re.search(r"(?im)^[ \t]*end[ \t]+module(?:[ \t]+z)?[ \t]*$", normalized)
        ),
        "types": types,
        "parameter_n": bool(
            re.search(
                r"(?im)^[ \t]*integer[ \t]*,[ \t]*parameter[ \t]*::[ \t]*n[ \t]*=[ \t]*100[ \t]*$",
                normalized,
            )
        ),
        "common_vars": bool(common),
        "executable_units": executable_units,
    }


def assert_exact_contract(source: str, parser_reference: str) -> dict[str, object]:
    inventory = declaration_inventory(source)
    assert inventory["module"] and inventory["end_module"]
    assert inventory["parameter_n"] and inventory["common_vars"]
    assert inventory["executable_units"] == []
    assert inventory["types"] == {
        "node_type": {"attributes": "sequence", "fields": ("x", "y")},
        "node_type1": {
            "attributes": "sequence private",
            "fields": ("x", "y"),
        },
        "node_type2": {
            "attributes": "private sequence",
            "fields": ("x", "y"),
        },
    }

    reference_inventory = declaration_inventory(parser_reference)
    assert reference_inventory["types"] == inventory["types"]
    assert reference_inventory["common_vars"]
    assert reference_inventory["executable_units"] == []
    return inventory


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument(
        "--compiler", default=None, help="accepted for runner compatibility"
    )
    arguments = parser.parse_args()
    del arguments.compiler

    source_dir = arguments.source_dir
    source = (source_dir / "program.f90").read_text(encoding="utf-8")
    parser_reference = (source_dir / "program_p.f90").read_text(encoding="utf-8")
    inventory = assert_exact_contract(source, parser_reference)
    print("oracle_module: Z")
    print("oracle_types: node_type,node_type1,node_type2 with fields x,y")
    print("oracle_common_layout: /vars/ contains ff(100) and bval")
    print(f"oracle_executable_units: {len(inventory['executable_units'])}")
    print("oracle_numerical_observable: undefined-no-entry-point")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
