#!/usr/bin/env python3
"""Three-test contract for the pinned v377 MPI invalid-source boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
DEFAULT_UPSTREAM = CASE.parents[2] / "upstream" / "tapenade"
if not DEFAULT_UPSTREAM.is_dir():
    DEFAULT_UPSTREAM = Path("/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade")
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(DEFAULT_UPSTREAM)))
FORTAD = Path(
    os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad")
)
SOURCE_DIR = UPSTREAM / "todoF90" / "REFERENCES" / "v377"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class V377ContractTests(unittest.TestCase):
    def test_manifest_pins_sources_and_invalid_boundary(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)

        self.assertEqual(manifest["classification"], "expected-refusal-invalid-upstream")
        self.assertEqual(manifest["source_form"], "free")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a",
        )
        self.assertEqual(manifest["selected_entry_points"], ["test(ce,rank)", "main"])
        self.assertIn("MPI_SEND", " ".join(manifest["expected_diagnostics"]))
        self.assertIn("no bounded port", manifest["closure"])
        for relative, expected in manifest["upstream_sha256"].items():
            source = UPSTREAM / relative
            self.assertTrue(source.is_file(), source)
            self.assertEqual(sha256(source), expected, relative)

    def test_independent_compiler_and_communication_oracles(self) -> None:
        flags = [
            "-std=f2018",
            "-ffree-form",
            "-ffree-line-length-none",
            "-pedantic-errors",
            "-Wall",
            "-Wextra",
            "-Wimplicit-interface",
            "-cpp",
        ]
        with tempfile.TemporaryDirectory(prefix="fortad-v377-contract-") as directory:
            output = Path(directory)
            exact = subprocess.run(
                [
                    os.environ.get("FC", "mpifort"),
                    *flags,
                    f"-I{SOURCE_DIR}",
                    f"-J{output / 'exact-mod'}",
                    "-c",
                    str(SOURCE_DIR / "program.f90"),
                    "-o",
                    str(output / "program.o"),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(exact.returncode, 0)
            self.assertIn("More actual than formal arguments", exact.stderr)

            for reference in ("program_d.f90", "program_b.f90"):
                compiled = subprocess.run(
                    [
                        os.environ.get("FC", "mpifort"),
                        *flags,
                        f"-I{SOURCE_DIR}",
                        f"-J{output / reference}",
                        "-c",
                        str(SOURCE_DIR / reference),
                        "-o",
                        str(output / f"{reference}.o"),
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(
                    compiled.returncode,
                    0,
                    f"{reference}:\n{compiled.stdout}\n{compiled.stderr}",
                )

        oracle = subprocess.run(
            ["python3", str(CASE / "oracle.py")],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("rank0-receives-from-invalid-minus-one", oracle.stdout)
        self.assertIn("rank1-sends-to-inactive-rank-two", oracle.stdout)

    def test_result_records_all_pinned_engine_boundaries(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "classification: expected-refusal-invalid-upstream",
            "upstream_exact_strict_compile: program=1 tangent=0 reverse=0 topd=0 topb=0 admpi_support=0",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=1 tangent=0 reverse=0 admpi_support=0",
            "fortad_exact_parser: transform=0 generated=strict-compile-1",
            'fortad_exact_forward: expected-refusal status=1 output=none diagnostic="no derivative rule for the call to MPI_irecv"',
            'fortad_exact_reverse: expected-refusal status=1 output=none diagnostic="reverse loop accumulates nothing"',
            "oracle_status: pass rank0-receives-from-invalid-minus-one rank1-sends-to-inactive-rank-two",
            "port_result: not-applicable-no-standard-conforming-semantics-to-preserve",
        ):
            self.assertIn(marker, report)

        self.assertTrue((FORTAD / "build" / "fo" / "bin" / "fortad").is_file())
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip(),
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )


if __name__ == "__main__":
    unittest.main(verbosity=1)
