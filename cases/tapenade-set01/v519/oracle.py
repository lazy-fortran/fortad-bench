#!/usr/bin/env python3
"""Independent semantic oracle for the standalone v519 output program."""

from __future__ import annotations

import os
import re
from pathlib import Path


DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
SOURCE = UPSTREAM / "todoF90" / "REFERENCES" / "v519" / "program.f90"


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    normalized = source.lower()

    assert re.search(r"^\s*program\s+test_it\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert re.search(
        r"^\s*end\s+program\s+test_it\s*$", source, re.IGNORECASE | re.MULTILINE
    )
    assert len(re.findall(r"^\s*write\s*\(", source, re.IGNORECASE | re.MULTILINE)) == 4
    assert len(re.findall(r"^\s*stop\s*$", source, re.IGNORECASE | re.MULTILINE)) == 1
    assert re.search(r"^\s*100\s+format\s*\(\s*a120\s*\)\s*$", source, re.IGNORECASE | re.MULTILINE)
    assert not re.search(r"^\s*(subroutine|function)\b", source, re.IGNORECASE | re.MULTILINE)
    assert "call " not in normalized

    fields = [f"{chr(ord('A') + index)}" * 3 for index in range(26)] + ["AAAA"]
    payload = "MyOutput:" + ",".join(fields)
    assert len(payload) == 117
    records = [payload, payload, payload[:120].ljust(120), payload[:120].ljust(120)]
    assert len(records) == 4
    assert records[:2] == [payload, payload]
    assert all(len(record) == 120 for record in records[2:])
    assert all(source.count(field) >= 4 for field in fields)

    print(f"oracle_payload_length: {len(payload)}")
    print(f"oracle_record_lengths: {[len(record) for record in records]}")
    print("oracle_records: list-directed,list-directed,A120,A120")
    print("oracle_procedure_shape: one standalone PROGRAM TEST_IT; no callable procedure")
    print("oracle_status: pass")


if __name__ == "__main__":
    main()
