#!/usr/bin/env python3
"""Independent strict-compiler oracle for the invalid lh056 source set."""

from __future__ import annotations

import argparse
import re
import subprocess
import tempfile
from pathlib import Path


STRICT_FLAGS = [
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-fsyntax-only",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-cpp",
]

EXPECTED = {
    "program.f": (1, ("Different type kinds", "not compatible with an intrinsic")),
    "program_p.f": (1, ("Different type kinds", "not compatible with an intrinsic")),
    "program_d.f": (0, ()),
    "program_b.f": (0, ()),
    "program_dv.f": (1, ("Cannot open included file",)),
}


def compile_source(compiler: str, source: Path, work: Path) -> tuple[int, str]:
    completed = subprocess.run(
        [compiler, *STRICT_FLAGS, "-I", str(source.parent), "-J", str(work), str(source)],
        cwd=work,
        capture_output=True,
        text=True,
        check=False,
    )
    return completed.returncode, completed.stdout + completed.stderr


def diagnostic_lines(log: str) -> list[str]:
    return [line.strip() for line in log.splitlines() if re.search(r"(?:Error|Fatal Error):", line)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()

    source_root = args.source_root.resolve()
    sources = [source_root / name for name in EXPECTED]
    if any(not source.is_file() for source in sources):
        raise SystemExit("lh056 source closure is incomplete")

    with tempfile.TemporaryDirectory(prefix="lh056-oracle-") as temporary:
        observations = [compile_source(args.compiler, source, Path(temporary)) for source in sources]

    for source, (status, log) in zip(sources, observations):
        expected_status, markers = EXPECTED[source.name]
        if status != expected_status or any(marker not in log for marker in markers):
            raise SystemExit(
                f"{source.name} did not reproduce its expected compiler behavior "
                f"(status={status}, expected={expected_status})"
            )
        marker_text = ",".join(markers) if markers else "none-required"
        print(f"oracle_{source.name}: status={status} diagnostics={marker_text}")
        for line in diagnostic_lines(log)[:5]:
            print(f"oracle_{source.name}_diagnostic: {line}")
    print("oracle_status: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
