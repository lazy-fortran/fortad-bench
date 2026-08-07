#!/usr/bin/env python3
"""Independent contracts for the bd04 exact-source refusal boundary."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


CASE = Path(__file__).resolve().parent
ROOT = CASE.parents[2]
UPSTREAM = Path(os.environ.get("TAPENADE_REPO", str(ROOT / "upstream" / "tapenade")))
FORTAD_ROOT = Path(os.environ.get("FORTAD_REPO", "/mnt/storage/code/lazy-fortran/fortad"))
FORTAD = FORTAD_ROOT / "build" / "fo" / "bin" / "fortad"
SOURCE = UPSTREAM / "nonRegressions" / "set01" / "bd04"
MANIFEST = CASE / "manifest.toml"
RESULT = CASE / "result.txt"
STRICT = [
    "-std=f2018",
    "-ffixed-form",
    "-ffixed-line-length-none",
    "-fsyntax-only",
    "-pedantic-errors",
    "-Wall",
    "-Wextra",
    "-Wimplicit-interface",
    "-fno-lto",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_oracle() -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(CASE / "oracle.py"), str(SOURCE)],
        capture_output=True,
        text=True,
        check=False,
    )


class Bd04Contracts(unittest.TestCase):
    def test_manifest_and_exact_source_contract(self) -> None:
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["source_form"], "fixed")
        self.assertEqual(manifest["upstream_entry_point"], "toto(a)")
        self.assertEqual(
            manifest["upstream_revision"],
            "e59864cab441d4175df75383b3ff58c3dcd26df9",
        )
        self.assertEqual(
            manifest["fortad_revision"],
            "72ca2aa1c6c7d4b171b13a3e13c5190944080032",
        )
        self.assertEqual(
            {
                name: sha256(SOURCE / name)
                for name in manifest["upstream_sha256"]
            },
            manifest["upstream_sha256"],
        )
        oracle = run_oracle()
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        self.assertIn("oracle_status: pass", oracle.stdout)

    def test_fresh_tapenade_parser_forward_reverse_strict_compile(self) -> None:
        tapenade = UPSTREAM / "bin" / "tapenade"
        self.assertTrue(tapenade.is_file())
        oracle = run_oracle()
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        with tempfile.TemporaryDirectory(prefix="bd04-contract-tapenade-") as temporary:
            work = Path(temporary)
            for mode, suffix in (("p", "p"), ("d", "d"), ("b", "b")):
                output = work / mode
                output.mkdir()
                command = [str(tapenade), f"-{mode}"]
                if mode != "p":
                    command += ["-root", "toto"]
                command += ["-O", str(output), "-o", "bd04", str(SOURCE / "program.f")]
                generated = subprocess.run(
                    command, cwd=UPSTREAM, capture_output=True, text=True
                )
                self.assertEqual(
                    generated.returncode, 0, generated.stdout + generated.stderr
                )
                source = output / f"bd04_{suffix}.f"
                self.assertTrue(source.is_file())
                compiled = subprocess.run(
                    ["gfortran", *STRICT, str(source)],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

    def test_fortad_exact_parser_forward_reverse_refusals(self) -> None:
        self.assertTrue(FORTAD.is_file())
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(FORTAD_ROOT), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout.strip(),
            "72ca2aa1c6c7d4b171b13a3e13c5190944080032",
        )
        oracle = run_oracle()
        self.assertEqual(oracle.returncode, 0, oracle.stdout + oracle.stderr)
        with tempfile.TemporaryDirectory(prefix="bd04-contract-fortad-") as temporary:
            work = Path(temporary)
            attempts = [
                (
                    "parser",
                    [
                        str(FORTAD),
                        "check",
                        "--output",
                        str(work / "parser.f90"),
                        str(SOURCE / "program.f"),
                    ],
                    work / "parser.f90",
                ),
                (
                    "forward",
                    [
                        str(FORTAD),
                        "--mode",
                        "forward",
                        "--indep",
                        "a",
                        "--dep",
                        "a",
                        "--proc",
                        "toto",
                        "--name",
                        "bd04_forward",
                        "--module",
                        "bd04_forward_mod",
                        "--output",
                        str(work / "forward.f90"),
                        str(SOURCE / "program.f"),
                    ],
                    work / "forward.f90",
                ),
                (
                    "reverse",
                    [
                        str(FORTAD),
                        "--mode",
                        "reverse",
                        "--indep",
                        "a",
                        "--dep",
                        "a",
                        "--proc",
                        "toto",
                        "--name",
                        "bd04_reverse",
                        "--module",
                        "bd04_reverse_mod",
                        "--output",
                        str(work / "reverse.f90"),
                        str(SOURCE / "program.f"),
                    ],
                    work / "reverse.f90",
                ),
            ]
            for label, command, output in attempts:
                completed = subprocess.run(command, capture_output=True, text=True)
                self.assertNotEqual(
                    completed.returncode, 0, f"{label}: {completed.stdout}{completed.stderr}"
                )
                self.assertIn(
                    "fortad: unsupported statement at line 26",
                    completed.stdout + completed.stderr,
                )
                self.assertFalse(output.exists())

    def test_result_records_the_independent_oracle_and_refusal_boundary(self) -> None:
        report = RESULT.read_text(encoding="utf-8")
        for marker in (
            "runner_result: pass",
            "upstream_exact_strict_compile: program.f=0",
            "stored_strict_compile: parser=0 forward=0 reverse=0",
            "tapenade_generation: parser=0 tangent=0 reverse=0",
            "tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0",
            "fortad_exact_parser: expected-refusal status=1 output=none",
            "fortad_exact_forward: expected-refusal status=1 output=none",
            "fortad_exact_reverse: expected-refusal status=1 output=none",
            "unsupported statement at line 26",
            "oracle_trace: 100 visits, rows and columns 1..10 in order",
            "oracle_jvp:",
            "oracle_vjp:",
            "oracle_status: pass",
        ):
            self.assertIn(marker, report)


if __name__ == "__main__":
    unittest.main(verbosity=1)
