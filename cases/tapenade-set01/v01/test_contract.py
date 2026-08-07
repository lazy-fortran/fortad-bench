#!/usr/bin/env python3
"""Three-test behavioral contract for the todoF90/REFERENCES/v01 case."""

from __future__ import annotations

import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
BENCH = CASE.parents[2]
UPSTREAM_ROOT = Path(
    os.environ.get("TAPENADE_REPO", str(BENCH / "upstream" / "tapenade"))
)
FORTAD_ROOT = Path(
    os.environ.get("FORTAD_REPO", str(BENCH.parent / "fortad"))
)
if not FORTAD_ROOT.is_dir() and Path("/mnt/storage/code/lazy-fortran/fortad").is_dir():
    FORTAD_ROOT = Path("/mnt/storage/code/lazy-fortran/fortad")
SOURCE_DIR = UPSTREAM_ROOT / "todoF90" / "REFERENCES" / "v01"
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"


class V01ContractTests(unittest.TestCase):
    def test_manifest_pins_exact_refusal_boundary(self) -> None:
        with (CASE / "manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(manifest["classification"], "expected-refusal")
        self.assertEqual(
            manifest["upstream_entry_point"],
            "flinopen_work(filename,iideb,iilen,jjdeb,jjlen,do_test,iim,jjm,llm,lon,lat,lev,ttm,itaus,date0,dt,fid_out)",
        )
        self.assertIn(
            "todoF90/REFERENCES/v01/flincom.mod", manifest["upstream_sources"]
        )
        self.assertIn("program_p.f90", manifest["missing_stored_references"])
        self.assertIn("No bounded port is claimed", manifest["closure"])

    def test_independent_strict_compiler_oracle(self) -> None:
        strict_flags = [
            "-std=f2018",
            "-ffree-form",
            "-ffree-line-length-none",
            "-pedantic-errors",
            "-Wall",
            "-Wextra",
            "-Wimplicit-interface",
            "-cpp",
        ]
        with tempfile.TemporaryDirectory(prefix="fortad-v01-contract-") as directory:
            output = Path(directory)
            for label, source in (
                ("program", SOURCE_DIR / "program.f90"),
                ("program_d", SOURCE_DIR / "program_d.f90"),
            ):
                (output / label).mkdir()
                completed = subprocess.run(
                    [
                        "gfortran",
                        *strict_flags,
                        f"-I{SOURCE_DIR}",
                        f"-J{output / label}",
                        "-c",
                        str(source),
                        "-o",
                        str(output / f"{label}.o"),
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(
                    completed.returncode,
                    0,
                    f"{label}:\n{completed.stdout}\n{completed.stderr}",
                )

    def test_result_and_fortad_diagnostic_contract(self) -> None:
        report = (CASE / "result.txt").read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal",
            "upstream_exact_strict_compile: program.f90=0 program_d.f90=0",
            "tapenade_generation: parser=pass forward=pass reverse=pass",
            "tapenade_fresh_strict_compile: parser=0 forward=0 reverse=0",
            "fortad_exact_parser: expected-refusal",
            "fortad_exact_forward: expected-refusal",
            "fortad_exact_reverse: expected-refusal",
            "bounded_port: not-claimed",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)

        self.assertTrue(FORTAD.is_file(), FORTAD)
        with tempfile.TemporaryDirectory(prefix="fortad-v01-fortad-") as directory:
            output = Path(directory)
            indep = (
                "filename,iideb,iilen,jjdeb,jjlen,do_test,iim,jjm,llm,lon,lat,lev,"
                "ttm,date0,dt,fid_out"
            )
            requests = (
                (
                    "parser",
                    [
                        "check",
                        "--proc",
                        "flinopen_work",
                        "-o",
                        str(output / "parser.f90"),
                    ],
                ),
                (
                    "forward",
                    [
                        "--mode",
                        "forward",
                        "--indep",
                        indep,
                        "--proc",
                        "flinopen_work",
                        "--output",
                        str(output / "forward.f90"),
                    ],
                ),
                (
                    "reverse",
                    [
                        "--mode",
                        "reverse",
                        "--indep",
                        indep,
                        "--dep",
                        "itaus",
                        "--proc",
                        "flinopen_work",
                        "--output",
                        str(output / "reverse.f90"),
                    ],
                ),
            )
            for label, arguments in requests:
                completed = subprocess.run(
                    [str(FORTAD), *arguments, str(SOURCE_DIR / "program.f90")],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertNotEqual(
                    completed.returncode,
                    0,
                    f"FortAD unexpectedly accepted {label}: {completed.stdout}",
                )
                self.assertIn(
                    "unsupported allocation lifetime construct",
                    completed.stderr,
                )
                self.assertIn("line 9", completed.stderr)
                self.assertFalse((output / f"{label}.f90").exists())


if __name__ == "__main__":
    unittest.main()
