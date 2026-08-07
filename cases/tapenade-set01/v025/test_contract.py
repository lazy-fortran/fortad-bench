#!/usr/bin/env python3
"""Exactly three behavioral tests for the v025 no-entry boundary."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
UPSTREAM_CANDIDATE = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(UPSTREAM_CANDIDATE)))
SOURCE_DIR = UPSTREAM / "nonRegressions" / "set04" / "v025"
TAPENADE = UPSTREAM / "bin" / "tapenade"
STRICT_FLAGS = (
    "-std=f2018",
    "-ffree-form",
    "-ffree-line-length-none",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-cpp",
)


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


class V025ContractTests(unittest.TestCase):
    def test_exact_sources_compile_strictly(self) -> None:
        """The exact primal and stored parser reference are compilable modules."""
        revision = run(["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"])
        self.assertEqual(
            revision.stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
            revision.stderr,
        )
        with tempfile.TemporaryDirectory(prefix="fortad-v025-exact-") as directory:
            scratch = Path(directory)
            for name in ("program.f90", "program_p.f90"):
                module_dir = scratch / name.replace('.f90', '-mod')
                module_dir.mkdir()
                compiled = run(
                    [
                        "gfortran",
                        *STRICT_FLAGS,
                        f"-I{SOURCE_DIR}",
                        f"-J{module_dir}",
                        "-c",
                        str(SOURCE_DIR / name),
                        "-o",
                        str(scratch / f"{name}.o"),
                    ]
                )
                self.assertEqual(
                    compiled.returncode,
                    0,
                    f"{name}:\n{compiled.stdout}\n{compiled.stderr}",
                )

    def test_fresh_tapenade_no_root_behavior(self) -> None:
        """Fresh probes distinguish parser rendering from no-root AD refusal."""
        with tempfile.TemporaryDirectory(prefix="fortad-v025-tapenade-") as directory:
            scratch = Path(directory)
            for mode, option, suffix in (
                ("parser", "-p", "p"),
                ("forward", "-d", "d"),
                ("reverse", "-b", "b"),
            ):
                output = scratch / mode
                output.mkdir()
                generated = run(
                    [
                        str(TAPENADE),
                        option,
                        "-O",
                        ".",
                        "-o",
                        "v025",
                        str(SOURCE_DIR / "program.f90"),
                    ],
                    cwd=output,
                )
                self.assertEqual(
                    generated.returncode,
                    0,
                    f"{mode}:\n{generated.stdout}\n{generated.stderr}",
                )
                self.assertTrue((output / f"v025_{suffix}.msg").is_file())
                if mode == "parser":
                    source = output / "v025_p.f90"
                    self.assertTrue(source.is_file())
                    parser_module_dir = scratch / "parser-mod"
                    parser_module_dir.mkdir()
                    compiled = run(
                        [
                            "gfortran",
                            *STRICT_FLAGS,
                            f"-I{SOURCE_DIR}",
                            f"-J{parser_module_dir}",
                            "-c",
                            str(source),
                            "-o",
                            str(scratch / "parser.o"),
                        ]
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stderr)
                else:
                    self.assertFalse((output / f"v025_{suffix}.f90").exists())
                    message = (output / f"v025_{suffix}.msg").read_text()
                    self.assertIn("No root unit to differentiate", message)
                    self.assertIn("The code provided does not contain a top procedure", message)

    def test_independent_module_semantic_oracle(self) -> None:
        """An independent model confirms the empty callable/derivative domain."""
        oracle = run(["python3", str(CASE / "oracle.py"), str(SOURCE_DIR / "program.f90")])
        self.assertEqual(oracle.returncode, 0, oracle.stderr)
        self.assertIn("oracle_status: pass", oracle.stdout)
        self.assertIn("module_count: 5", oracle.stdout)
        self.assertIn("saved_real_variable_count: 6", oracle.stdout)
        self.assertIn("callable_or_executable_units: 0", oracle.stdout)
        self.assertIn("derivative_domain: empty-no-entry-point", oracle.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
