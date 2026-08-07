#!/usr/bin/env python3
"""Independent strict-compiler closure oracle for Tapenade set01 lh035."""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path


def compile_rejected(compiler: str, source: Path, directory: Path) -> tuple[int, str]:
    object_file = directory / (source.stem + ".o")
    completed = subprocess.run(
        [
            compiler,
            "-std=f2018",
            "-pedantic-errors",
            "-Wall",
            "-Wextra",
            "-ffixed-line-length-none",
            "-fno-lto",
            "-c",
            str(source),
            "-o",
            str(object_file),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    return completed.returncode, completed.stdout + completed.stderr


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()

    source_dir = args.source_dir.resolve()
    exact = source_dir / "program.f"
    stored_parser = source_dir / "program_p.f"
    if not exact.is_file() or not stored_parser.is_file():
        raise SystemExit("lh035 exact or stored parser source is missing")

    with tempfile.TemporaryDirectory(prefix="fortad-lh035-oracle-") as temporary:
        directory = Path(temporary)
        exact_status, exact_log = compile_rejected(args.compiler, exact, directory)
        stored_status, stored_log = compile_rejected(
            args.compiler, stored_parser, directory
        )

    if exact_status == 0 or stored_status == 0:
        raise SystemExit(
            f"compiler unexpectedly accepted lh035: exact={exact_status} "
            f"stored_parser={stored_status}"
        )
    for label, log in (("exact", exact_log), ("stored_parser", stored_log)):
        if "Cannot convert CHARACTER(10) to REAL(4)" not in log:
            raise SystemExit(f"{label} rejection lacks the character-to-real diagnostic")

    print(f"oracle_exact_status: {exact_status}")
    print(f"oracle_stored_parser_status: {stored_status}")
    print("oracle_reason: strict compiler rejects incompatible t declarations and assignment")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
