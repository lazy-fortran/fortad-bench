"""Canonicalize next10 probe records using the established shard recorder."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "tapenade-queue-shard-next8/record.py"
SPEC = importlib.util.spec_from_file_location("next8_record", SOURCE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load recorder: {SOURCE}")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
MODULE.CASE = Path(__file__).resolve().parent


def compiler_check(source: str) -> dict[str, dict[str, object]]:
    """Use the source's real fixed/free form for exact compiler evidence."""
    case = MODULE.UPSTREAM / Path(source).parent
    name = Path(source).name
    fixed = Path(source).suffix.lower() in {".f", ".for", ".ftn", ".f77"}
    form = "-ffixed-form" if fixed else "-ffree-form"
    length = "-ffixed-line-length-none" if fixed else "-ffree-line-length-none"
    checks = {}
    with tempfile.TemporaryDirectory(prefix="fortad-next10-", dir="/var/tmp") as module_dir:
        for label, standard in (("strict", "-std=f2018"), ("legacy", "-std=legacy")):
            process = subprocess.run(
                ["gfortran", standard, "-fsyntax-only", form, length,
                 "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface",
                 f"-J{module_dir}", name], cwd=case, capture_output=True,
                text=True, check=False,
            )
            checks[label] = {
                "status": "pass" if process.returncode == 0 else "refused",
                "returncode": process.returncode,
                "command": ["gfortran", standard, "-fsyntax-only", form, length,
                             "-pedantic-errors", "-Wall", "-Wextra", "-Wimplicit-interface",
                             "-J$MODULE_DIR", name],
                "stderr": MODULE.normalize(process.stderr, case),
            }
    return checks


MODULE.compiler_check = compiler_check

if __name__ == "__main__":
    raise SystemExit(MODULE.main())
