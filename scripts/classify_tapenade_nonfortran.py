#!/usr/bin/env python3
"""Materialize evidence-neutral ledger rows for non-Fortran candidates."""

from __future__ import annotations

import argparse
import csv
import io
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TRIAGE = ROOT / "docs" / "corpora" / "tapenade-static.jsonl"
DEFAULT_LEDGER = ROOT / "docs" / "corpora" / "tapenade-status.csv"
KNOWN_TARGET_LANGUAGES = frozenset({"c", "c++", "cuda", "julia"})
TARGET_LANGUAGES = KNOWN_TARGET_LANGUAGES | {"unknown"}
LEDGER_COLUMNS = (
    "component",
    "path",
    "language",
    "source_form_hint",
    "initial_classification",
    "status",
    "entry_point",
    "tapenade_options",
    "modes",
    "oracle",
    "dependencies",
    "tapenade_result",
    "fortad_result",
)
UNSUPPORTED_LANGUAGE_FIELDS = {
    "status": "fortad-unsupported-source-language",
    "entry_point": "not-inspected",
    "tapenade_options": "not-inspected",
    "modes": "not-inspected",
    "oracle": "not-applicable-no-fortad-run",
    "dependencies": "not-inspected",
    "tapenade_result": "not-run",
    "fortad_result": "not-run-unsupported-source-language",
}
UNKNOWN_SOURCE_FIELDS = {
    "status": "no-recognized-source",
    "entry_point": "not-inspected",
    "tapenade_options": "not-inspected",
    "modes": "not-inspected",
    "oracle": "not-applicable-no-recognized-source",
    "dependencies": "not-inspected",
    "tapenade_result": "not-run",
    "fortad_result": "not-run-no-recognized-source",
}


class ClassificationError(RuntimeError):
    """The static report and ledger do not support a safe materialization."""


def read_triage(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as stream:
        rows = [json.loads(line) for line in stream]
    keys = [(row["component"], row["path"]) for row in rows]
    if len(keys) != len(set(keys)):
        raise ClassificationError("static triage contains duplicate candidate keys")
    return rows


def read_ledger(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        if tuple(reader.fieldnames or ()) != LEDGER_COLUMNS:
            raise ClassificationError("status ledger columns differ from schema")
        return list(reader)


def _validate_target_triage(row: dict) -> None:
    language = row["language"]
    classification = row["classification"]
    if language == "unknown":
        if classification != "harness-reference-data":
            raise ClassificationError(
                f"unknown candidate {row['path']} is not harness/reference data"
            )
        return
    if classification != "non-fortran-source":
        raise ClassificationError(
            f"{language} candidate {row['path']} is not classified non-Fortran"
        )


def classified_fields(language: str) -> dict[str, str]:
    if language == "unknown":
        return UNKNOWN_SOURCE_FIELDS
    return UNSUPPORTED_LANGUAGE_FIELDS


def materialize(
    ledger_rows: list[dict[str, str]], triage_rows: list[dict]
) -> tuple[list[dict[str, str]], Counter]:
    triage = {
        (row["component"], row["path"]): row
        for row in triage_rows
    }
    ledger_keys = [(row["component"], row["path"]) for row in ledger_rows]
    if set(ledger_keys) != set(triage):
        raise ClassificationError("static triage and status ledger keys differ")

    counts: Counter = Counter()
    materialized = []
    for row in ledger_rows:
        key = (row["component"], row["path"])
        static = triage[key]
        if row["language"] != static["language"]:
            raise ClassificationError(f"language differs for {row['path']}")
        if row["source_form_hint"] != static["source_form_hint"]:
            raise ClassificationError(f"source form differs for {row['path']}")

        updated = dict(row)
        if static["language"] in TARGET_LANGUAGES:
            _validate_target_triage(static)
            expected_fields = classified_fields(static["language"])
            existing = {field: row[field] for field in expected_fields}
            seed = {
                "status": "untriaged",
                "entry_point": "untriaged",
                "tapenade_options": "untriaged",
                "modes": "untriaged",
                "oracle": "untriaged",
                "dependencies": "untriaged",
                "tapenade_result": "not-run",
                "fortad_result": "not-run",
            }
            if existing != seed and existing != expected_fields:
                raise ClassificationError(
                    f"refusing to overwrite curated target row {row['path']}"
                )
            updated.update(expected_fields)
            counts[static["language"]] += 1
        materialized.append(updated)
    return materialized, counts


def render(rows: list[dict[str, str]]) -> str:
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=LEDGER_COLUMNS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return stream.getvalue()


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--triage", type=Path, default=DEFAULT_TRIAGE)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument(
        "--check", action="store_true", help="fail if materialization would change the ledger"
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    current = read_ledger(arguments.ledger)
    expected, counts = materialize(current, read_triage(arguments.triage))
    rendered = render(expected)
    if arguments.check:
        # CSV quoting is presentation; the audit is about the materialized
        # records and must not reject equivalent serialized rows.
        if current != expected:
            print("Tapenade non-Fortran ledger classifications are stale")
            return 1
    else:
        arguments.ledger.write_text(rendered, encoding="utf-8")
    summary = " ".join(
        f"{language}={counts[language]}" for language in sorted(counts)
    )
    print(f"classified {sum(counts.values())} rows: {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
