#!/usr/bin/env python3
"""Behavioral checks for the study-corpus fetch and license inventory helpers."""

import csv
import hashlib
import json
import subprocess
import sys
import tempfile
import tomllib
import unittest
from collections import Counter
from pathlib import Path
from unittest.mock import patch

import fetch_upstreams


class LicenseInventoryTests(unittest.TestCase):
    def test_license_inventory_records_exact_commit_and_tree(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkout = root / "upstream" / "fixture"
            checkout.mkdir(parents=True)
            (checkout / "LICENSE").write_text("fixture license\n")
            subprocess.run(["git", "init", "-q", str(checkout)], check=True)
            subprocess.run(["git", "-C", str(checkout), "config", "user.name", "fixture"], check=True)
            subprocess.run(
                ["git", "-C", str(checkout), "config", "user.email", "fixture@example.invalid"],
                check=True,
            )
            subprocess.run(["git", "-C", str(checkout), "add", "LICENSE"], check=True)
            subprocess.run(["git", "-C", str(checkout), "commit", "-qm", "fixture"], check=True)
            expected_revision = subprocess.run(
                ["git", "-C", str(checkout), "rev-parse", "HEAD"],
                check=True, capture_output=True, text=True,
            ).stdout.strip()
            expected_tree = subprocess.run(
                ["git", "-C", str(checkout), "rev-parse", "HEAD^{tree}"],
                check=True, capture_output=True, text=True,
            ).stdout.strip()

            generated = root / "docs" / "generated"
            entry = {"name": "fixture", "ref": expected_revision, "license": "MIT"}
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", root / "upstream"), \
                    patch.object(fetch_upstreams, "GENERATED", generated):
                fetch_upstreams.scan_licenses([entry])

            inventory = (generated / "license-inventory.md").read_text()
            self.assertIn(
                f"| fixture | {expected_revision} | {expected_revision} | "
                f"{expected_tree} | MIT | LICENSE |",
                inventory,
            )

    def test_license_filename_matching_is_case_insensitive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkout = root / "upstream" / "fixture"
            checkout.mkdir(parents=True)
            (checkout / "License.txt").write_text("fixture license\n")
            generated = root / "docs" / "generated"

            entry = {"name": "fixture", "ref": "deadbeef", "license": "MIT"}
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", root / "upstream"), \
                    patch.object(fetch_upstreams, "GENERATED", generated):
                fetch_upstreams.scan_licenses([entry])

            inventory = (generated / "license-inventory.md").read_text()
            self.assertIn("License.txt", inventory)
            self.assertNotIn("NONE FOUND", inventory)

    def test_unavailable_requested_ref_is_a_fetch_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            target = root / "upstream" / "fixture"
            source.mkdir()
            subprocess.run(["git", "init", "-q", str(source)], check=True)
            subprocess.run(["git", "-C", str(source), "config", "user.name", "fixture"], check=True)
            subprocess.run(["git", "-C", str(source), "config", "user.email", "fixture@example.invalid"], check=True)
            (source / "LICENSE").write_text("fixture license\n")
            subprocess.run(["git", "-C", str(source), "add", "LICENSE"], check=True)
            subprocess.run(["git", "-C", str(source), "commit", "-qm", "fixture"], check=True)

            entry = {"name": "fixture", "url": source.as_uri(), "ref": "missing", "license": "MIT"}
            with patch.object(fetch_upstreams, "DEST", root / "upstream"):
                self.assertFalse(fetch_upstreams.clone(entry, depth=1))

    def test_metadata_entries_are_not_reported_as_missing_licenses(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            generated = root / "docs" / "generated"
            entry = {"name": "fixture", "ref": "web", "license": "METADATA-ONLY"}
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", root / "upstream"), \
                    patch.object(fetch_upstreams, "GENERATED", generated):
                fetch_upstreams.scan_licenses([entry])

            inventory = (generated / "license-inventory.md").read_text()
            self.assertIn("METADATA ONLY", inventory)
            self.assertIn("Entries with no licence file: 0.", inventory)


class CorpusFetchTests(unittest.TestCase):
    def make_source(self, root: Path) -> tuple[Path, str, str]:
        source = root / "source"
        source.mkdir()
        subprocess.run(["git", "init", "-q", str(source)], check=True)
        subprocess.run(["git", "-C", str(source), "config", "user.name", "fixture"], check=True)
        subprocess.run(
            ["git", "-C", str(source), "config", "user.email", "fixture@example.invalid"],
            check=True,
        )
        files = {
            "LICENSE.md": "fixture license\n",
            "corpus/set01/case_a/program.f90": (
                "program a\n"
                "  use iso_fortran_env, only: real64\n"
                "  include 'fixture.inc'\n"
                "#include \"pre.inc\"\n"
                "contains\n"
                "  subroutine step()\n"
                "  end subroutine step\n"
                "end program a\n"
            ),
            "corpus/set01/case_b/program.c": "#include <math.h>\nvoid b(void) {}\n",
            "aux/test.jl": "using LinearAlgebra\nf(x) = x\n",
        }
        for relative, contents in files.items():
            path = source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents)
        subprocess.run(["git", "-C", str(source), "add", "."], check=True)
        subprocess.run(["git", "-C", str(source), "commit", "-qm", "fixture"], check=True)
        revision = subprocess.run(
            ["git", "-C", str(source), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        tree = subprocess.run(
            ["git", "-C", str(source), "rev-parse", "HEAD^{tree}"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        return source, revision, tree

    def write_manifest(
        self,
        root: Path,
        source: Path,
        revision: str,
        tree: str,
        *,
        with_ledger: bool = False,
        with_triage: bool = False,
    ) -> None:
        manifest = root / "docs" / "corpora" / "fixture.toml"
        manifest.parent.mkdir(parents=True)
        license_digest = hashlib.sha256(b"fixture license\n").hexdigest()
        ledger = 'status_ledger = "docs/corpora/fixture-status.csv"\n' if with_ledger else ""
        triage = 'static_triage = "docs/corpora/fixture-static.jsonl"\n' if with_triage else ""
        manifest.write_text(
            f'''schema_version = 1
name = "fixture"
upstream = "fixture"
origin = "{source.as_uri()}"
revision = "{revision}"
tree = "{tree}"
license = "MIT"
license_file = "LICENSE.md"
license_sha256 = "{license_digest}"
expected_tracked_files = 4
expected_manifest_files = 3
expected_candidate_cases = 3
{ledger}
{triage}

[[component]]
id = "language-cases"
path = "corpus"
classification = "test language cases"
expected_tracked_files = 2
case_globs = ["set[0-9][0-9]/*"]
case_type = "directory"
expected_candidate_cases = 2

[[component]]
id = "auxiliary-case"
path = "aux"
classification = "test auxiliary case"
expected_tracked_files = 1
case_globs = ["*.jl"]
case_type = "file"
expected_candidate_cases = 1
'''
        )

    def test_static_triage_is_reproducible_and_uses_tracked_source_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = self.make_source(root)
            self.write_manifest(root, source, revision, tree, with_triage=True)
            destination = root / "upstream"
            entry = {
                "name": "fixture",
                "url": source.as_uri(),
                "ref": revision,
                "license": "MIT",
                "corpus_manifest": "docs/corpora/fixture.toml",
            }
            outside = root / "outside.f90"
            outside.write_text("program escaped\nend program escaped\n")
            symlink = source / "corpus" / "set01" / "case_a" / "escape.f90"
            symlink.symlink_to(outside)
            self.assertEqual(
                fetch_upstreams._static_source_hints(source, [
                    "corpus/set01/case_a/escape.f90"
                ]),
                ([], [], []),
            )
            expected = [
                {
                    "classification": "fortran-runnable-candidate",
                    "component": "language-cases",
                    "entry_point_hints": [
                        {
                            "kind": "program",
                            "name": "a",
                            "source": "corpus/set01/case_a/program.f90",
                        },
                        {
                            "kind": "subroutine",
                            "name": "step",
                            "source": "corpus/set01/case_a/program.f90",
                        },
                    ],
                    "include_hints": [
                        {
                            "source": "corpus/set01/case_a/program.f90",
                            "target": "fixture.inc",
                        },
                        {
                            "source": "corpus/set01/case_a/program.f90",
                            "target": "pre.inc",
                        },
                    ],
                    "language": "fortran",
                    "path": "corpus/set01/case_a",
                    "schema_version": 1,
                    "source_files": ["corpus/set01/case_a/program.f90"],
                    "source_form_hint": "free",
                    "use_hints": [
                        {
                            "name": "iso_fortran_env",
                            "source": "corpus/set01/case_a/program.f90",
                        }
                    ],
                },
                {
                    "classification": "non-fortran-source",
                    "component": "language-cases",
                    "entry_point_hints": [
                        {
                            "kind": "function",
                            "name": "b",
                            "source": "corpus/set01/case_b/program.c",
                        }
                    ],
                    "include_hints": [
                        {
                            "source": "corpus/set01/case_b/program.c",
                            "target": "math.h",
                        }
                    ],
                    "language": "c",
                    "path": "corpus/set01/case_b",
                    "schema_version": 1,
                    "source_files": ["corpus/set01/case_b/program.c"],
                    "source_form_hint": "n/a",
                    "use_hints": [],
                },
                {
                    "classification": "non-fortran-source",
                    "component": "auxiliary-case",
                    "entry_point_hints": [
                        {
                            "kind": "function",
                            "name": "f",
                            "source": "aux/test.jl",
                        }
                    ],
                    "include_hints": [],
                    "language": "julia",
                    "path": "aux/test.jl",
                    "schema_version": 1,
                    "source_files": ["aux/test.jl"],
                    "source_form_hint": "n/a",
                    "use_hints": [
                        {"name": "LinearAlgebra", "source": "aux/test.jl"}
                    ],
                },
            ]
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", destination):
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                inventory = fetch_upstreams.audit_corpus(entry)
                self.assertEqual(fetch_upstreams.static_triage_rows(inventory), expected)
                first = fetch_upstreams.render_static_triage(inventory)
                second = fetch_upstreams.render_static_triage(inventory)
                self.assertEqual(second, first)
                self.assertEqual(
                    [json.loads(line) for line in first.splitlines()],
                    expected,
                )

                report = fetch_upstreams.write_static_triage(inventory)
                self.assertEqual(fetch_upstreams.audit_static_triage(inventory), 3)
                report.write_bytes(first.replace(b'"math.h"', b'"wrong.h"', 1))
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "differs"):
                    fetch_upstreams.audit_static_triage(inventory)
                report.write_bytes(first)

                checkout = destination / "fixture"
                (checkout / ".git" / "info" / "exclude").write_text("ignored.f90\n")
                ignored = checkout / "corpus" / "set01" / "case_a" / "ignored.f90"
                ignored.write_text("program ignored\nend program ignored\n")
                clean_inventory = fetch_upstreams.audit_corpus(entry)
                self.assertEqual(fetch_upstreams.render_static_triage(clean_inventory), first)

    def test_status_ledger_seed_is_reproducible_and_covers_every_candidate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = self.make_source(root)
            self.write_manifest(root, source, revision, tree, with_ledger=True)
            destination = root / "upstream"
            entry = {
                "name": "fixture",
                "url": source.as_uri(),
                "ref": revision,
                "license": "MIT",
                "corpus_manifest": "docs/corpora/fixture.toml",
            }
            expected = (
                "component,path,language,source_form_hint,initial_classification,"
                "status,entry_point,tapenade_options,modes,oracle,dependencies,"
                "tapenade_result,"
                "fortad_result\n"
                "language-cases,corpus/set01/case_a,fortran,free,test language cases,"
                "untriaged,untriaged,untriaged,untriaged,untriaged,untriaged,"
                "not-run,not-run\n"
                "language-cases,corpus/set01/case_b,c,n/a,test language cases,"
                "untriaged,untriaged,untriaged,untriaged,untriaged,untriaged,"
                "not-run,not-run\n"
                "auxiliary-case,aux/test.jl,julia,n/a,test auxiliary case,"
                "untriaged,untriaged,untriaged,untriaged,untriaged,untriaged,"
                "not-run,not-run\n"
            )
            self.assertEqual(
                fetch_upstreams._candidate_source_hints(
                    "case", ["case/kernel.C", "case/kernel.cu"]
                ),
                ("c++|cuda", "n/a"),
            )
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", destination):
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                inventory = fetch_upstreams.audit_corpus(entry)
                first = fetch_upstreams.render_initial_corpus_ledger(inventory)
                second = fetch_upstreams.render_initial_corpus_ledger(inventory)
                self.assertEqual(first, expected)
                self.assertEqual(second.encode(), first.encode())

                ledger = fetch_upstreams.write_initial_corpus_ledger(inventory)
                self.assertEqual(ledger.read_text(), expected)
                self.assertEqual(fetch_upstreams.audit_corpus_ledger(inventory), 3)

                unsupported = expected.replace(",not-run,not-run\n", ",passed,not-run\n", 1)
                ledger.write_text(unsupported)
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "untriaged status row"):
                    fetch_upstreams.audit_corpus_ledger(inventory)

                curated = expected.replace(
                    ",untriaged,untriaged,untriaged,untriaged,untriaged,untriaged,"
                    "not-run,not-run\n",
                    ",classified,a,none,forward,hand derivative,none,passed,not-run\n",
                    1,
                )
                ledger.write_text(curated)
                self.assertEqual(fetch_upstreams.audit_corpus_ledger(inventory), 3)
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "refusing to overwrite"):
                    fetch_upstreams.write_initial_corpus_ledger(inventory)
                ledger.write_text(expected)

                checkout = destination / "fixture"
                (checkout / ".git" / "info" / "exclude").write_text("ignored.cpp\n")
                (checkout / "corpus" / "set01" / "case_a" / "ignored.cpp").write_text(
                    "void ignored() {}\n"
                )
                clean_inventory = fetch_upstreams.audit_corpus(entry)
                self.assertEqual(
                    fetch_upstreams.render_initial_corpus_ledger(clean_inventory),
                    expected,
                )

    def test_status_ledger_audit_rejects_missing_or_reordered_candidates(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = self.make_source(root)
            self.write_manifest(root, source, revision, tree, with_ledger=True)
            destination = root / "upstream"
            entry = {
                "name": "fixture",
                "url": source.as_uri(),
                "ref": revision,
                "license": "MIT",
                "corpus_manifest": "docs/corpora/fixture.toml",
            }
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", destination):
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                inventory = fetch_upstreams.audit_corpus(entry)
                ledger = fetch_upstreams.write_initial_corpus_ledger(inventory)
                lines = ledger.read_text().splitlines()
                ledger.write_text("\n".join(lines[:-1]) + "\n")
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "2 status rows"):
                    fetch_upstreams.audit_corpus_ledger(inventory)

                ledger.write_text("\n".join([lines[0], lines[2], lines[1], lines[3]]) + "\n")
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "unexpected path"):
                    fetch_upstreams.audit_corpus_ledger(inventory)

                ledger.write_text("\n".join([lines[0], lines[1], lines[1], lines[3]]) + "\n")
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "unexpected path"):
                    fetch_upstreams.audit_corpus_ledger(inventory)

                changed_language = lines[1].replace(",fortran,free,", ",c,n/a,")
                ledger.write_text(
                    "\n".join([lines[0], changed_language, lines[2], lines[3]]) + "\n"
                )
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "unexpected language"):
                    fetch_upstreams.audit_corpus_ledger(inventory)

    def test_pinned_commit_fetch_and_corpus_audit_are_offline(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = self.make_source(root)
            self.write_manifest(root, source, revision, tree)
            destination = root / "upstream"
            generated = root / "docs" / "generated"
            entry = {
                "name": "fixture",
                "url": source.as_uri(),
                "ref": revision,
                "license": "MIT",
                "corpus_manifest": "docs/corpora/fixture.toml",
            }
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", destination), \
                    patch.object(fetch_upstreams, "GENERATED", generated):
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                inventory = fetch_upstreams.audit_corpus(entry)
                out = fetch_upstreams.write_corpus_inventory(inventory)

            self.assertEqual(inventory["revision"], revision)
            self.assertEqual(inventory["tracked_files"], 4)
            self.assertEqual(inventory["manifest_files"], 3)
            self.assertEqual(inventory["candidate_cases"], 3)
            report = out.read_text()
            self.assertIn("Presence in this inventory does not claim FortAD support.", report)
            self.assertIn("language-cases:corpus/set01/case_a", report)

    def test_audit_rejects_an_incomplete_materialized_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = self.make_source(root)
            self.write_manifest(root, source, revision, tree)
            destination = root / "upstream"
            entry = {
                "name": "fixture",
                "url": source.as_uri(),
                "ref": revision,
                "license": "MIT",
                "corpus_manifest": "docs/corpora/fixture.toml",
            }
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", destination):
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                (destination / "fixture" / "corpus" / "set01" / "case_a" / "program.f90").unlink()
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "incomplete checkout"):
                    fetch_upstreams.audit_corpus(entry)

    def test_pinned_fetch_repairs_an_incomplete_existing_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = self.make_source(root)
            self.write_manifest(root, source, revision, tree)
            destination = root / "upstream"
            entry = {
                "name": "fixture",
                "url": source.as_uri(),
                "ref": revision,
                "license": "MIT",
                "corpus_manifest": "docs/corpora/fixture.toml",
            }
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", destination):
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                checkout = destination / "fixture"
                missing = checkout / "corpus" / "set01" / "case_a" / "program.f90"
                missing.unlink()
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                inventory = fetch_upstreams.audit_corpus(entry)
                tracked = checkout / "corpus" / "set01" / "case_a" / "program.f90"
                tracked.write_text("local edit\n")
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                self.assertEqual(tracked.read_text(), "local edit\n")
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "checkout is modified"):
                    fetch_upstreams.audit_corpus(entry)

            self.assertEqual(inventory["revision"], revision)
            self.assertTrue(missing.is_file())

    def test_audit_rejects_modified_and_untracked_materialized_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = self.make_source(root)
            self.write_manifest(root, source, revision, tree)
            destination = root / "upstream"
            entry = {
                "name": "fixture",
                "url": source.as_uri(),
                "ref": revision,
                "license": "MIT",
                "corpus_manifest": "docs/corpora/fixture.toml",
            }
            generated = root / "docs" / "generated"
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", destination), \
                    patch.object(fetch_upstreams, "GENERATED", generated):
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                checkout = destination / "fixture"
                report = fetch_upstreams.write_corpus_inventory(
                    fetch_upstreams.audit_corpus(entry)
                )
                self.assertTrue(report.is_file())
                tracked = checkout / "corpus" / "set01" / "case_a" / "program.f90"
                original = tracked.read_text()
                tracked.write_text("subroutine changed\nend subroutine changed\n")
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "checkout is modified"):
                    fetch_upstreams.audit_corpus(entry)
                self.assertEqual(fetch_upstreams.scan_corpora([entry]), ["fixture"])
                self.assertFalse(report.exists())

                tracked.write_text(original)
                untracked = checkout / "untracked.f90"
                untracked.write_text("end\n")
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "checkout is modified"):
                    fetch_upstreams.audit_corpus(entry)

                untracked.unlink()
                tracked.write_text("subroutine hidden\nend subroutine hidden\n")
                subprocess.run(
                    [
                        "git", "-C", str(checkout), "update-index", "--assume-unchanged",
                        "corpus/set01/case_a/program.f90",
                    ],
                    check=True,
                )
                status = subprocess.run(
                    ["git", "-C", str(checkout), "status", "--porcelain=v1"],
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout
                self.assertEqual(status, "")
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "non-default index flags"):
                    fetch_upstreams.audit_corpus(entry)

    def test_failed_fetch_discards_a_prior_corpus_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            generated = root / "docs" / "generated"
            generated.mkdir(parents=True)
            stale = generated / "fixture-corpus.md"
            stale.write_text("stale\n")
            entry = {
                "name": "fixture",
                "url": "https://example.invalid/fixture.git",
                "ref": "0" * 40,
                "license": "MIT",
                "corpus_manifest": "docs/corpora/fixture.toml",
            }
            argv = ["fetch_upstreams.py", "--corpus", "fixture"]
            with patch.object(fetch_upstreams, "ROOT", root), \
                    patch.object(fetch_upstreams, "DEST", root / "upstream"), \
                    patch.object(fetch_upstreams, "GENERATED", generated), \
                    patch.object(fetch_upstreams, "load", return_value=[entry]), \
                    patch.object(fetch_upstreams, "clone", return_value=False), \
                    patch.object(fetch_upstreams, "scan_licenses"), \
                    patch.object(sys, "argv", argv):
                self.assertEqual(fetch_upstreams.main(), 1)
            self.assertFalse(stale.exists())


class CommittedTapenadeLedgerTests(unittest.TestCase):
    def test_committed_ledger_has_complete_scaffold_and_curated_cases(self):
        root = Path(__file__).resolve().parent.parent
        with (root / "docs" / "corpora" / "tapenade.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        ledger = root / manifest["status_ledger"]
        expected_columns = [
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
        ]
        with ledger.open(encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream)
            self.assertEqual(reader.fieldnames, expected_columns)
            rows = list(reader)

        self.assertEqual(len(rows), manifest["expected_candidate_cases"])
        self.assertEqual(len(rows), 2014)
        self.assertEqual(
            len({(row["component"], row["path"]) for row in rows}),
            2014,
        )
        self.assertTrue(all(row["initial_classification"] for row in rows))
        evidence_paths = {
            "nonRegressions/set01/bd01",
            "nonRegressions/set01/bd02",
            "nonRegressions/set01/bd03",
            "nonRegressions/set01/lh001",
            "nonRegressions/set01/lh002",
            "nonRegressions/set01/lh012",
            "nonRegressions/set01/lh013",
            "nonRegressions/set01/lh014",
            "nonRegressions/set01/lh003",
            "nonRegressions/set01/lh019",
            "nonRegressions/set01/lh004",
            "nonRegressions/set01/lh005",
            "nonRegressions/set01/lh006",
            "nonRegressions/set01/lh008",
            "nonRegressions/set01/lh010",
            "nonRegressions/set01/lh023",
            "nonRegressions/set01/lh032",
            "nonRegressions/set01/lh049",
            "nonRegressions/set01/lh134",
            "nonRegressions/set01/lh066",
            "nonRegressions/set01/lh088",
            "nonRegressions/set01/bd06",
            "nonRegressions/set01/bd01",
            "nonRegressions/set01/bd02",
            "nonRegressions/set01/bd03",
            "nonRegressions/set01/lh057",
            "nonRegressions/set01/lh058",
            "nonRegressions/set01/lh068",
            "todoF90/REFERENCES/v420",
            "nonRegressions/set12/f03typf01",
            "ADFirstAidKit/testMemSizef.f",
            "ADFirstAidKit/validityTest.f",
            "nonRegressions/set01/lh016",
            "nonRegressions/set01/lh017",
            "nonRegressions/set01/lh022",
            "nonRegressions/set01/lh028",
            "nonRegressions/set01/lh033",
            "nonRegressions/set01/lh039",
            "nonRegressions/set01/lh040",
            "nonRegressions/set01/lh074",
            "nonRegressions/set01/lh080",
            "nonRegressions/set01/lh082",
            "nonRegressions/set01/lh081",
            "nonRegressions/set01/lh083",
            "nonRegressions/set01/lh084",
            "nonRegressions/set01/lh085",
            "nonRegressions/set01/lh092",
            "nonRegressions/set01/lh086",
            "nonRegressions/set01/lh087",
            "nonRegressions/set01/lh089",
            "nonRegressions/set01/lh090",
            "nonRegressions/set01/lh093",
            "nonRegressions/set01/lh094",
            "nonRegressions/set01/lh097",
            "nonRegressions/set01/lh098",
            "nonRegressions/set01/lh102",
            "nonRegressions/set01/lh103",
            "nonRegressions/set01/B01",
            "nonRegressions/set01/lh091",
            "nonRegressions/set01/lh095",
            "nonRegressions/set01/lh096",
            "nonRegressions/set01/B03",
            "nonRegressions/set01/ala03",
            "nonRegressions/set01/ala00",
            "nonRegressions/set01/ala01",
            "nonRegressions/set01/ala02",
            "nonRegressions/set01/ala04",
            "nonRegressions/set01/ala05",
            "nonRegressions/set01/bd04",
            "nonRegressions/set01/ht02",
            "nonRegressions/set01/ht03",
            "nonRegressions/set01/lh104",
            "nonRegressions/set01/lh105",
            "nonRegressions/set01/lh107",
            "nonRegressions/set01/lh109",
            "nonRegressions/set01/lh018",
            "nonRegressions/set01/lh007",
            "nonRegressions/set01/lh011",
            "nonRegressions/set01/bd05",
            "nonRegressions/set01/lh020",
            "nonRegressions/set01/lh021",
            "nonRegressions/set01/lh024",
            "nonRegressions/set01/lh025",
            "nonRegressions/set01/lh026",
            "nonRegressions/set01/lh027",
            "nonRegressions/set01/lh029",
            "nonRegressions/set01/lh030",
            "nonRegressions/set01/lh031",
            "nonRegressions/set01/lh034",
            "nonRegressions/set01/lh038",
            "nonRegressions/set01/lh041",
            "nonRegressions/set01/lh045",
            "nonRegressions/set01/lh047",
            "nonRegressions/set01/lh048",
            "nonRegressions/set01/lh050",
            "nonRegressions/set01/lh051",
            "nonRegressions/set01/lh053",
            "nonRegressions/set01/lh054",
            "nonRegressions/set01/lh055",
            "nonRegressions/set01/lh059",
                "nonRegressions/set01/lh060",
                "nonRegressions/set01/lh061",
                "nonRegressions/set01/lh064",
                "nonRegressions/set01/lh067",
                "nonRegressions/set01/lh069",
                "nonRegressions/set01/lh070",
                "nonRegressions/set01/lh072",
                "nonRegressions/set01/lh073",
                "nonRegressions/set01/lh076",
                "nonRegressions/set01/lh077",
                "todoF90/REFERENCES/bd01",
                "todoF90/REFERENCES/bd11",
                "todoF90/REFERENCES/v01",
                "todoF90/REFERENCES/v02",
                "todoF90/REFERENCES/v100",
                "todoF90/REFERENCES/v101",
                "todoF90/REFERENCES/v413",
                "todoF90/REFERENCES/v414",
                "todoF90/REFERENCES/v415",
                "todoF90/REFERENCES/v416",
                "todoF90/REFERENCES/v417",
                "todoF90/REFERENCES/v419",
                "todoF90/REFERENCES/v422",
            "todoF90/REFERENCES/v425",
            "todoF90/REFERENCES/v426",
            "todoF90/REFERENCES/v427",
            "todoF90/REFERENCES/v469",
            "todoF90/REFERENCES/v500",
            "todoF90/REFERENCES/v504",
            "todoF90/REFERENCES/v505",
            "todoF90/REFERENCES/v508",
            "todoF90/REFERENCES/v519",
            "todoF90/REFERENCES/v526",
            "todoF90/REFERENCES/v547",
            "nonRegressions/set01/lh000",
            "nonRegressions/set02/v065",
            "nonRegressions/set04/v017",
            "nonRegressions/set04/v025",
            "nonRegressions/set05/v075",
            "nonRegressions/set05/v146",
            "nonRegressions/set05/v147",
            "nonRegressions/set05/v171",
            "nonRegressions/set05/v177",
            "nonRegressions/set05/v201",
            "nonRegressions/set05/v216",
            "nonRegressions/set06/v316",
            "nonRegressions/set06/v317",
            "nonRegressions/set06/v320",
            "nonRegressions/set06/v360",
            "nonRegressions/set06/v362",
            "nonRegressions/set07/v485",
            "nonRegressions/set07/v523",
            "nonRegressions/set07/v544",
            "nonRegressions/set11/vpf16",
            "nonRegressions/set01/lh136",
            "nonRegressions/set01/lh144",
            "nonRegressions/set02/lh163",
            "nonRegressions/set02/lh192",
            "nonRegressions/set02/lh196",
            "nonRegressions/set02/lh198",
            "nonRegressions/set02/v103",
            "nonRegressions/set02/v128",
            "nonRegressions/set02/v130",
            "nonRegressions/set03/ht05",
            "nonRegressions/set03/ht06",
            "nonRegressions/set03/ht12",
            "nonRegressions/set03/ht13",
            "nonRegressions/set04/lh128",
            "nonRegressions/set04/lh148",
            "nonRegressions/set04/lh151",
            "nonRegressions/set04/lh152",
            "nonRegressions/set02/lh150",
            "nonRegressions/set03/ht09",
            "nonRegressions/set04/lh110",
            "nonRegressions/set05/v052",
            "nonRegressions/set05/v054",
            "nonRegressions/set05/v060",
            "nonRegressions/set05/v061",
            "nonRegressions/set05/v062",
            "nonRegressions/set05/v064",
            "nonRegressions/set05/v065",
            "nonRegressions/set05/v067",
            "nonRegressions/set05/v125",
            "nonRegressions/set05/v137",
            "nonRegressions/set05/v150",
            "nonRegressions/set05/v168",
            "nonRegressions/set06/v234",
            "nonRegressions/set06/v314",
            "nonRegressions/set06/v379",
            "nonRegressions/set12/cmplxstep01",
            "nonRegressions/set12/f03fptr01",
            "nonRegressions/set12/jlb012",
            "nonRegressions/set12/profile01",
        }
        evidence = [
            row for row in rows
            if row["status"] in {"runnable-ported", "expected-refusal"}
        ]
        language_exclusions = [
            row for row in rows
            if row["status"] in {
                "fortad-unsupported-source-language", "no-recognized-source"
            }
        ]
        untriaged = [row for row in rows if row["status"] == "untriaged"]
        blocked = [row for row in rows if row["status"] == "blocked-missing-dependency"]
        self.assertEqual(
            [
                (
                    row["path"],
                    row["entry_point"],
                    row["tapenade_result"],
                    row["fortad_result"],
                )
                for row in blocked
            ],
            [
                (
                    "nonRegressions/set02/lh193",
                    "head(x,y)",
                    "not-run-missing-dependency",
                    "not-run-missing-dependency",
                ),
                (
                    "nonRegressions/set02/lh194",
                    "head(x,y)",
                    "not-run-missing-dependency",
                    "not-run-missing-dependency",
                ),
            ],
        )
        self.assertEqual({row["path"] for row in evidence}, evidence_paths)
        self.assertEqual(
            {row["status"] for row in evidence},
            {"runnable-ported", "expected-refusal"},
        )
        invalid = [
            row for row in rows
            if row["status"] == "unsupported-invalid-upstream-fortran"
        ]
        self.assertEqual(
            [(row["path"], row["fortad_result"]) for row in invalid],
            [
                ("nonRegressions/set01/lh009", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh015", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh035", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh036", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh037", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh042", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh044", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh046", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh052", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh056", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh063", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh065", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh071", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh075", "not-run-invalid-upstream-source"),
                ("nonRegressions/set01/lh078", "forward-generated-strict-compile-refusal-reverse-expected-refusal-no-output"),
                ("nonRegressions/set01/lh079", "check-pass-forward-refusal-undeclared-independent-reverse-refusal-undeclared-dependent"),
                ("nonRegressions/set05/v066", "not-run-invalid-upstream-source"),
                ("nonRegressions/set05/v068", "not-run-invalid-upstream-source"),
                ("nonRegressions/set05/v069", "expected-refusal-exact-parser-forward-reverse-no-output"),
                ("todoF90/REFERENCES/v05", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v07", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v144", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v270", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v322", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v377", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v385", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v402", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v412", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v418", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v421", "not-run-invalid-upstream-source"),
                ("todoF90/REFERENCES/v503", "not-run-invalid-upstream-source"),
            ],
        )
        self.assertEqual(len(language_exclusions), 508)
        for column in (
            "entry_point", "tapenade_options", "modes", "oracle", "dependencies"
        ):
            self.assertEqual({row[column] for row in untriaged}, {"untriaged"})
            self.assertNotIn("untriaged", {row[column] for row in evidence})
            self.assertNotIn("untriaged", {row[column] for row in language_exclusions})
        self.assertEqual({row["tapenade_result"] for row in untriaged}, {"not-run"})
        self.assertEqual({row["fortad_result"] for row in untriaged}, {"not-run"})
        self.assertNotIn("not-run", {row["tapenade_result"] for row in evidence})
        self.assertEqual(
            {row["tapenade_result"] for row in language_exclusions},
            {"not-run"},
        )
        self.assertEqual(
            {row["fortad_result"] for row in evidence},
            {
                "pass-transform-compile-runtime",
                "refused-generated-reverse-does-not-compile",
                "unsupported-reverse-constant-loop",
                "unsupported-type-bound-call",
                "reverse-refused-branch-in-loop",
                "unsupported-program-not-procedure",
                "expected-refusal-generated-forward-reverse-strict-compile",
                "unsupported-common-block",
                "pass-forward-reverse-complex-adjoint-refusal",
                "pass-exact-source-refusal-unsupported-statement-line-11",
                "pass-exact-source-refusal-unmatched-do-line-37",
                "pass-exact-source-refusal-unterminated-character-line-49",
                "pass-forward-transform-reverse-generated-compile-refusal-indx-and-dependent-adjoint",
                "pass-forward-transform-reverse-generated-compile-refusal-duplicate-adjoint",
                "pass-generated-compile-refusal-implicit-index",
                "pass-forward-transform-compile-reverse-refusal-per-iteration-storage",
                "pass-forward-transform-compile-reverse-refusal-loop-control-flow",
                "unsupported-statement-line-5-common",
                "unsupported-statement-line-4-character",
                "pass-exact-source-refusal-unsupported-statement-line-9",
                "pass-exact-source-refusal-unsupported-computed-goto-line-6",
                "pass-exact-source-refusal-common-line-6-normalized-port-pass",
                "pass-exact-source-refusal-common-line-5",
                "pass-exact-source-refusal-mutating-call-boundary",
                "pass-transform-compile-runtime-exact-source-refusal",
                "pass-forward-transform-compile-reverse-refusal-control-flow",
                "pass-forward-transform-compile-reverse-refusal-generated-compile",
                "refused-transform-oracle-mismatch",
                "pass-exact-source-refusal-implicit-y",
                "pass-bounded-forward-transform-compile-runtime-reverse-refusal",
                "exact-refusal-bounded-forward-transform-compile-runtime-reverse-not-claimed",
                "pass-forward-transform-compile-reverse-transform-compile-runtime",
                "exact-refusal-bounded-forward-and-y-reverse-transform-compile-runtime",
                "exact-refusal-bounded-forward-and-a-sum-reverse-transform-compile-runtime",
                "exact-refusal-bounded-forward-and-objective-reverse-transform-compile-runtime",
                "exact-forward-reverse-refusal-bounded-forward-pass-complex-reverse-refusal",
                "exact-refusal-bounded-forward-reverse-transform-compile-runtime",
                "exact-titi-call-refusal-exact-toto-pass-bounded-forward-reverse-transform-compile-runtime",
                "exact-refusal-bounded-forward-reverse-transform-compile-runtime",
                "expected-refusal-exact-parser-forward-reverse-no-output",
                "expected-refusal-exact-check-forward-reverse-function-inlining-no-output",
                "exact-parser-forward-generated-compile-refusal-reverse-refusal-bounded-forward-reverse-transform-compile-runtime",
                "exact-parser-transform-strict-compile-forward-reverse-refusal-bounded-forward-reverse-transform-compile-runtime",
                "exact-parser-forward-reverse-refusal-bounded-forward-reverse-transform-compile-runtime",
                "expected-refusal-exact-parser-forward-reverse-unsupported-return-statement",
                "exact-forward-reverse-expected-refusal-external-call-inlining-no-output",
                "pass-exact-check-jvp-compile-expected-refusal-vjp-per-iteration-storage",
                "expected-refusal-exact-parser-forward-reverse-labeled-do",
                "expected-refusal-forward-reverse-generic-call-no-output",
                "forward-unsafe-generated-code-reverse-dependent-refusal",
                "expected-refusal-unsupported-statement-line-11-no-output",
                "pass-check-reemit; expected-refusal-forward-undeclared-a-and-reverse-undeclared-a",
                "generation-success-strict-compile-refusal-for-parser-forward-reverse",
                "expected-refusal-exact-parser-forward-reverse-no-output",
                "exact-parser-transform-strict-compile-refusal; exact-forward-reverse-pass",
                "exact-parser-forward-reverse-refusal-at-allocatable-context",
                "generation-success-strict-compile-refusal-parser-forward-reverse",
                "expected-refusal-exact-parser-forward-reverse-unsupported-module-line-1",
                "expected-refusal-exact-parser-forward-reverse-unsupported-allocatable-state",
                "exact-parser-forward-reverse-transform-strict-compile; bounded-port-forward-reverse-runtime-pass",
                "exact-parser-forward-reverse-refusal-unsupported-data-statement",
                "parser-forward-generation-strict-compile-refusal-reverse-refusal",
                "exact-parser-forward-reverse-refusal; bounded-port-forward-reverse-runtime-pass",
                "not-applicable-no-entry-point",
                "expected-refusal-exact-parser-forward-reverse-no-entry",
                "expected-refusal-exact-parser-forward-reverse-no-procedure",
                "expected-refusal-exact-parser-forward-reverse-unsupported-I-O-line-8-no-output",
                "expected-refusal-exact-forward-reverse-no-derivative-rule",
                "expected-refusal-exact-forward-reverse-no-derivative-rule-AAA-no-output",
                "expected-refusal-exact-parser-forward-reverse-unsupported-I-O-line-7-no-output",
                "check-jvp-vjp-pass-generated-compile-refusal-external-cnklog",
                "pass-check-jvp-vjp-compile-incomplete-output",
                "pass-check-jvp-expected-refusal-vjp-per-iteration-storage",
                "expected-refusal-check-forward-reverse-unsupported-read-line-7-no-output",
                "expected-refusal-check-forward-reverse-unsupported-common-line-33-no-output",
                "expected-refusal-parser-forward-reverse-unsupported-print-line-39-no-output",
                "expected-refusal-unsupported-print-line-39-no-output",
                "expected-refusal-modern-and-compatible-parser-forward-reverse-unsupported-print-line-39-no-output",
                "expected-refusal-check-jvp-vjp-legacy-do-line-116-no-output",
                "check-pass-expected-refusal-forward-reverse-external-update-no-output",
                "expected-refusal-exact-check-forward-independent-x-reverse-dependent-y-no-output",
                "expected-refusal-check-forward-reverse-unsupported-DO-WHILE-line-27-no-output",
                "expected-refusal-parser-forward-reverse-unsupported-print-statement-line-26",
                "pass-check-reemit-strict-and-legacy-free-compile; expected-top-call-refusal-and-direct-I-O-refusal-no-output",
                "pass-check-forward-strict-legacy-compile-expected-reverse-output-does-not-compile-both-gates",
                "pass-check-forward-strict-and-legacy-compile-expected-reverse-compile-refusal-duplicate-a_b",
                "pass-check-and-direct-p-d-b-generation-strict-compilation",
                "expected-refusal-exact-parser-forward-reverse-unsupported-common-line-6-no-output",
                "expected-refusal-source-first-and-compatibility-common-line-7-no-output",
                "expected-refusal-source-first-and-compatibility-reverse-undeclared-sub1",
                "expected-refusal-check-and-reverse-boundary-forward-pass",
                "pass-forward-expected-refusal-reverse-duplicate-x_b",
                "expected-refusal-array-section-line-5-no-output",
                "pass-exact-transform-compile-runtime",
                "expected-refusal-active-mutable-module-state",
                "expected-refusal-abstract-procedure-interface-procedure-pointer",
                "expected-refusal-allocation-line-6-no-output",
                "pass-forward-transform-compile-reverse-expected-refusal-loop-boundary",
                "pass-forward-expected-refusal-reverse-per-iteration-storage",
                "expected-refusal-generated-compile-hidden-extent-and-duplicate-adjoint",
                "pass-forward-transform-compile-reverse-generated-compile-refusal-duplicate-w_b",
                "expected-refusal-unsupported-INTRINSIC-declaration-line-30",
                "pass-forward-reverse-transform-compile-runtime",
                "pass-forward-reverse-transform-strict-compile-runtime",
                "expected-refusal-exact-check-forward-reverse-unsupported-common-line-32",
            },
        )
        expected_evidence = {
            "nonRegressions/set01/lh020": {
                "entry_point": "top(x,y,n,*); port set01_lh020(x,y,n,x1_out,branch)",
                "tapenade_options": "none",
                "modes": "forward|reverse:x1_out",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|branch-status",
                "dependencies": "alternate-return interface; bounded port exposes branch status",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh021": {
                "entry_point": "s1(x,i1,y,i2,z)",
                "tapenade_options": "-p|-d-root-s1|-b-root-s1",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-diagnostic",
                "dependencies": "COMMON /c1/; external S2/S3 definitions absent",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh024": {
                "entry_point": "test(x,y); sub1(v,t,y)",
                "tapenade_options": "-p|-d-root-test|-b-root-test",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "mutating call actuals; bounded port uses a plain temporary",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh025": {
                "entry_point": "funeval(a,x,n,k,lambda,y,z); port set01_lh025(a,x,lambda,y)",
                "tapenade_options": "-p|-d-root-funeval|-b-root-funeval",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-closed-form-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "exact source remains a generic Tapenade boundary; bounded port is N=7,K=3",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh026": {
                "entry_point": "s1(a,b)",
                "tapenade_options": "-p|-d-root-s1|-b-root-s1",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "restart-to-label branch inside a loop; stored reverse uses INTEGER*4",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh027": {
                "entry_point": "s1(a,b); port set01_lh027(a,b,a_out,b_out,objective)",
                "tapenade_options": "-p|-d-root-s1|-b-root-s1",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-closed-form-array-and-scalar-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "exact reverse references use legacy control flow; bounded port restricts to positive branch trace",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh029": {
                "entry_point": "s1(T,n,xx,z); s2(V,nn,res,z); s3(T,n,res,z); port set01_lh029(t,z,xx,z_out)",
                "tapenade_options": "-p|-d-root-s1|-b-root-s1",
                "modes": "forward|reverse:xx|reverse:z_out",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "external nested s2/s3 call boundary; bounded port unrolls the fixed trace",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh030": {
                "entry_point": "head(i1,i2,o); port set01_lh030(i1,i2,o)",
                "tapenade_options": "-p|-d-root-head|-b-root-head",
                "modes": "parser|forward|reverse|multidirectional",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-closed-form-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "exact COMMON /zz/ state; bounded port carries zn and zd as local state",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh031": {
                "entry_point": "sub1(x,y,z); port set01_lh031(x,y,z,x_out,y_out,z_out)",
                "tapenade_options": "-p|-d-root-sub1|-b-root-sub1",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-closed-form-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "exact RETURN boundary; bounded port exposes overwritten outputs",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh034": {
                "entry_point": "invert(f,x,a0,b0,n); port set01_lh034(a0,b0,x,n,root)",
                "tapenade_options": "-p|-d-root-invert|-b-root-invert",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "unresolved external callback; fixed-form RETURN boundary",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh038": {
                "entry_point": "top(x); port set01_lh038(pi,x)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "exact COMMON /ext/ boundary; bounded port makes state explicit; bounded reverse has duplicate x_b",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh041": {
                "entry_point": "adj10(tab,q); port set01_lh041(a,b,q,result)",
                "tapenade_options": "-p|-d-root-adj10|-b-root-adj10",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "exact COMMON/fixed-form nested-loop boundary; bounded port makes state explicit; bounded reverse needs per-iteration storage",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh045": {
                "entry_point": "S1(x,i1,y,i2,z); port set01_lh045(x,y,w4,v2,x_out,z,w4_out)",
                "tapenade_options": "-p|-d-root-S1|-b-root-S1",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "exact COMMON /c1/ and /c2/ state; bounded forward exposes state; bounded reverse has INTEGER*4/0.0_kind=8 compile boundary",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh047": {
                "entry_point": "adj13bis(u,z,t); sub1(u,y2,z,v); port set01_lh047(u,z,t,x1,x8,x9,x10,x11,y,v)",
                "tapenade_options": "-p|-d-root-adj13bis|-b-root-adj13bis",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "exact COMMON /cc/ state; scalar-to-array actual mismatch; bounded port exposes state and initializes v",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh048": {
                "entry_point": "adj13bis(u,z,t); port set01_lh048(u,z,t,v,x,y)",
                "tapenade_options": "-p|-d-root-adj13bis|-b-root-adj13bis",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "exact COMMON /cc/ state and incoming v; bounded port makes state explicit; bounded reverse duplicates t_b",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh050": {
                "entry_point": "sub0(x,y,z); port set01_lh050(x,y,z)",
                "tapenade_options": "-p|-d-root-sub0|-b-root-sub0",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "implicit-interface conditional omits the x>0 branch in exact FortAD; bounded port adds explicit INTENT and retains conditional state",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh051": {
                "entry_point": "adj1(x,y,z,n,o); port set01_lh051(x,y,z,n,o)",
                "tapenade_options": "-p|-d-root-adj1|-b-root-adj1",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|FortAD-diagnostic",
                "dependencies": "exact labeled DO at line 11; bounded reverse needs per-iteration storage for loop-carried z",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh053": {
                "entry_point": "cg12v4(z,tk,gamai,v,w,g,tau,ncmax); port set01_lh053(nc,z,tk,rcal,gamai,v,w,g,tau)",
                "tapenade_options": "-p|-d-root-cg12v4|-b-root-cg12v4",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "COMMON/EQUIVALENCE state; missing BINAIR and DIFFSIZES.inc dependencies; bounded port supplies fixed BINAIR algebra",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh054": {
                "entry_point": "test(n,m,lrhs,lbn,b,bpm,pp,*); port set01_lh054(n,m,lrhs,lbn,b,bpm,pp)",
                "tapenade_options": "-p|-d-root-test|-b-root-test",
                "modes": "parser|forward|reverse|multidirectional",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "absent DIFFSIZES.inc for stored multidirectional reference; exact alternate-return and implicit interface cause FortAD invalid forward and duplicate reverse b_b; bounded forward makes types and intents explicit",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set01/lh055": {
                "entry_point": "test(a,b); port set01_lh055(a,b)",
                "tapenade_options": "-p|-d-root-test|-b-root-test",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "REAL*8 and unresolved external TOTO in exact source; absent DIFFSIZES.inc in stored multidirectional reference; bounded witness fixes callback algebra and real64 intents",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh059": {
                "entry_point": "sub2(T,U,n,i); port set01_lh059(t,u,n,i)",
                "tapenade_options": "-p|-d-root-sub2|-b-root-sub2",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "labeled GOTO-5 state transition inside DO WHILE; absent DIFFSIZES.inc for stored multidirectional output; bounded port fixes the observed five-iteration trace",
                "tapenade_result": "pass-fresh-parser-tangent-generation-generated-compile-reverse-compile-refusal",
            },
            "nonRegressions/set01/lh060": {
                "entry_point": "invert(neq,y,savf,FX3,FX4); port set01_lh060(neq,y,savf,tn,c3,c4,y_out,savf_out,tn_out)",
                "tapenade_options": "-p|-d-root-invert|-b-root-invert",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "COMMON /ls0001/ TN and opaque FX3/FX4 callbacks; absent DIFFSIZES.inc blocks stored and fresh reverse; bounded port exposes state and fixes callback algebra",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh061": {
                    "entry_point": "test(y,f,jac,pjac,slvs)",
                    "tapenade_options": "-p|-d-root-test|-b-root-test",
                    "modes": "parser|forward|reverse",
                    "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-diagnostic",
                    "dependencies": "opaque external PJAC/JAC/F/SLVS callbacks have no definitions or derivative rules; absent DIFFSIZES.inc blocks stored multidirectional output",
                    "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-generated-compile",
                },
            "nonRegressions/set01/lh063": {
                "entry_point": "f(t)",
                "tapenade_options": "-p|-d-root-f|-b-root-f",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-diagnostic",
                "dependencies": "program.f defines global function f twice; strict Fortran rejects the duplicate definition; program_dv.f includes absent DIFFSIZES.inc; stored references are isolated single-procedure artifacts",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set01/lh064": {
                "entry_point": "cg02v1(T,n); truc(a); port set01_lh064(t,n)",
                "tapenade_options": "-p|-d-root-cg02v1|-b-root-cg02v1",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "exact fixed-form source has unreachable legacy FORMAT literals; Tapenade reverse uses INTEGER*4; bounded reverse needs per-iteration storage",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh065": {
                "entry_point": "top(in,out,N)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-pinned-Tapenade-generation|FortAD-diagnostic",
                "dependencies": "exact case passes REAL*8 arrays and REAL*8 COMMON state to INTEGER callbacks and changes COMMON layout; repairing it would change the upstream semantics",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh067": {
                "entry_point": "read7(z); port set01_lh067(z,read7)",
                "tapenade_options": "-p|-d-root-read7|-b-root-read7",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-diagnostic|independent-hand-JVP|central-difference-sweep|adjoint-identity|compiler-backed-generated-JVP",
                "dependencies": "exact fixed-form function has undeclared I/O names in error branches; program_dv.f requires absent DIFFSIZES.inc; bounded port claims only the successful-read path",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh069": {
                "entry_point": "loop2(a,b); port set01_lh069(a,b,n,ao,bo)",
                "tapenade_options": "-p|-d-root-loop2|-b-root-loop2",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "uninitialized local n controls a GOTO loop and program_dv.f requires absent DIFFSIZES.inc; bounded specialization makes n=10 and the one-iteration terminating path explicit",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh072": {
                "entry_point": "top(A,B); extf(B(10)); port set01_lh072(a_in,b_in,a_out,b_out,a_sum)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|compiled-FortAD-harness",
                "dependencies": "absent DIFFSIZES.inc blocks multidirectional reference; exact EXTF callback chain is external to FortAD; bounded port specializes EXTF(r)=r*r and exposes a_sum",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set01/lh073": {
                "entry_point": "top(A,B) via toto(extf,B); port set01_lh073(a_in,b_in,a_out,b_out,objective)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|compiled-FortAD-harness",
                "dependencies": "absent DIFFSIZES.inc blocks multidirectional reference; exact untyped external callback mutates actuals; bounded port specializes the observed EXTF square state transition",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set01/lh076": {
                "entry_point": "onegvert(pin4,emipint); port set01_lh076(pin4,emipint)",
                "tapenade_options": "-p|-d-root-onegvert|-b-root-onegvert",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|compiled-FortAD-harness",
                "dependencies": "absent DIFFSIZES.inc and legacy REAL*8/COMPLEX*16 declarations block exact/generated strict compilation; bounded port standardizes kinds and claims only complex JVP",
                "tapenade_result": "fresh-parser-tangent-reverse-generated-strict-compile-refusal",
            },
            "nonRegressions/set01/lh077": {
                "entry_point": "testinit(A,B,C); toto(T,S,R); port set01_lh077(a,b,c,c_out)",
                "tapenade_options": "-p|-d-root-testinit|-b-root-testinit",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|compiled-FortAD-harness",
                "dependencies": "absent DIFFSIZES.inc blocks multidirectional output; exact no-INTENT callback actuals are not plain writable variables for FortAD inlining; bounded explicit-interface port exposes c_out",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "todoF90/REFERENCES/bd01": {
                "entry_point": "titi(a,b,c); toto(a,b,c); port set01_bd01(a,b,c)",
                "tapenade_options": "-p/-d/-b-root-titi",
                "modes": "parser|forward|reverse|bounded-forward|bounded-reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-parser-and-exact-module-transform|FortAD-exact-call-boundary-diagnostic|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|compiled-FortAD-harness",
                "dependencies": "The exact TITI source uses module TATA/TOTO from a separate file; FortAD stops at the unresolved TOTO call; the bounded port inlines only the visible local TOTO body",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "todoF90/REFERENCES/bd11": {
                "entry_point": "top(i1,i2,i3); port top_bd11(i1,i2,i3,objective)",
                "tapenade_options": "-p|-d|-b -root top -nolib -ext REFERENCES/lh09/NoInlineABS",
                "modes": "parser|forward|reverse|bounded-forward|bounded-reverse-objective",
                "oracle": "strict-upstream-compilation|fresh-Tapenade-parser-tangent-reverse-generation-and-strict-compilation|FortAD-exact-check-forward-reverse-diagnostic|independent-hand-JVP-finite-difference-adjoint-identity|compiled-FortAD-bounded-forward-reverse-harness|upstream-source-sha256-contract",
                "dependencies": "The exact source has whole-array sections i2(:) and i1(:,i); FortAD refuses their noncontiguous and overlapping storage identity; the bounded port scalarizes the fixed 10-by-10 trace and exposes objective=i1(1,1)",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "todoF90/REFERENCES/v01": {
                "entry_point": "flinopen_work(filename,iideb,iilen,jjdeb,jjlen,do_test,iim,jjm,llm,lon,lat,lev,ttm,itaus,date0,dt,fid_out)",
                "tapenade_options": "-p/-d/-b-root-flinopen_work",
                "modes": "parser|forward|reverse",
                "oracle": "strict-gfortran-compile|fresh-pinned-Tapenade-generation-and-strict-compilation|FortAD-exact-parser-forward-reverse-diagnostic-and-no-output",
                "dependencies": "external NF90_INQUIRE_VARIABLE, NF90_GET_ATT, NF90_GET_VAR, and NF90_GET_VAR_D callbacks use implicit interfaces; flincom.mod is a pinned binary module artifact",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v02": {
                "entry_point": "modu.top(i1,i3,o1,o2,o3); port top_v02(i2_in,i3,o1,o2,o3)",
                "tapenade_options": "-nooptim spareinit|-p|-d|-b -root top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-pinned-Tapenade-parser-tangent-reverse-generation-and-compile|FortAD-exact-parser-forward-reverse-transform-and-strict-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|compiled-FortAD-forward-reverse-harness",
                "dependencies": "the exact module carries i2 as hidden mutable state and legacy implicit interfaces; the bounded port exposes i2_in and keeps i3 inout without claiming the hidden-state interface",
                "tapenade_result": "pass-fresh-parser-tangent-generation-reverse-strict-compile-refusal",
            },
            "todoF90/REFERENCES/v100": {
                "entry_point": "head(x,y); port head_v100_port(x_in,x_out,y)",
                "tapenade_options": "-p|-d|-b-root-head",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-exact-parser-forward-reverse-boundary|independent-MOD-domain-equivalence|central-difference-sweep|adjoint-identity|compiled-FortAD-bounded-forward-reverse-harness",
                "dependencies": "the exact source contains a strict-format tab and MOD has no derivative rule; the bounded port exposes x_out and claims only the open interval 0.2 < x_in(1) < 0.4",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v101": {
                "entry_point": "head(x,y); port head_v101(x,y)",
                "tapenade_options": "-association byaddress -vars x -outvars y|-p|-d|-b",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-exact-parser-forward-reverse-refusal|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|compiled-FortAD-bounded-forward-reverse-harness",
                "dependencies": "the exact routine allocates and deallocates a local rank-one array; the bounded port specializes the normal allocated fixed-size a(2) path and does not claim allocation failure or unallocated-state behavior",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v413": {
                "entry_point": "f4(t,ss,hr)",
                "tapenade_options": "-p|-d|-b-root-f4",
                "modes": "parser|forward|reverse",
                "oracle": "strict-gfortran-compile-of-exact-and-stored-forward-source|fresh-pinned-Tapenade-parser-tangent-reverse-generation-and-strict-compilation|FortAD-exact-parser-forward-reverse-boundary|independent-undefined-local-state-model|upstream-source-sha256-contract",
                "dependencies": "local mt is read before assignment, so the exact procedure has no defined numerical value",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-strict-compile-with-undefined-local-warning",
            },
            "todoF90/REFERENCES/v414": {
                "entry_point": "example3.addvector(a,b)",
                "tapenade_options": "-association-byaddress|-p|-d|-b-root-addvector",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler-for-exact-primal-and-stored-tangent|fresh-pinned-Tapenade-parser-tangent-reverse-generation-and-strict-compilation|FortAD-exact-parser-forward-reverse-generation-and-strict-compilation-boundary|independent-x-component-finite-difference-JVP|independent-x-component-adjoint-identity",
                "dependencies": "the exact source leaves addvector%y undefined; FortAD lacks the private derived-type context in generated outputs",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v415": {
                "entry_point": "calc_force(geom,prop,obj,acc)",
                "tapenade_options": "-p/-d/-b-root-calc_force|Options",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-pinned-Tapenade-generation-and-strict-compile|FortAD-exact-parser-forward-reverse-boundary|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|upstream-source-sha256-contract",
                "dependencies": "stored program_d is invalid; exact derived types contain allocatable components and FortAD stops before transformation",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v416": {
                "entry_point": "precechcin(x,y,nm_ha,Tm_ha); port set01_v416(x,y,nm_ha,Tm_ha)",
                "tapenade_options": "-association byaddress|-p|-d|-b-root-precechcin",
                "modes": "parser|forward|reverse",
                "oracle": "strict-gfortran exact-source and stored-reference boundary|fresh pinned Tapenade parser/tangent/reverse generation and strict compilation|FortAD exact parser/forward/reverse transform and generated-source compilation|independent matrix recurrence finite-difference and JVP/VJP adjoint oracle|pinned-source SHA-256 contract",
                "dependencies": "exact source has declaration-order failure; bounded port changes only declaration order and states nm_ha >= 2 with finite nonzero Tm_ha",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v417": {
                "entry_point": "calc_force(geom,prop,obj,acc)",
                "tapenade_options": "-association byaddress|-p/-d/-b -root calc_force",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-pinned-Tapenade-generation-and-strict-compile|FortAD-exact-parser-forward-reverse-boundary|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|upstream-source-sha256-contract",
                "dependencies": "exact derived types contain allocatable components; FortAD stops at the allocatable declaration",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v419": {
                "entry_point": "ROOT(X); program MAIN",
                "tapenade_options": "-head root -context -association byaddress|-p/-d/-b-root-ROOT",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler-diagnostics|fresh-pinned-Tapenade-parser-tangent-reverse-generation-and-strict-compile|FortAD-exact-parser-forward-reverse-refusal|independent-numeric-prefix-and-undefined-read-semantic-oracle|upstream-source-SHA-256-contract",
                "dependencies": "SUM is applied to assumed-size X and allocated-but-unassigned state is read; repairing bounds or allocation changes the candidate",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-strict-compile-refusal",
            },
            "todoF90/REFERENCES/v422": {
                "entry_point": "m1.f4(t)",
                "tapenade_options": "-association byaddress|-p/-d/-b-root-f4",
                "modes": "parser|forward|reverse",
                "oracle": "independent-hand-model-of-defined-t-mutation|central-difference-JVP-check|hand-VJP-adjoint-identity|independent-source-level-undefined-function-result-check|upstream-source-and-stored-reference-SHA-256-contract",
                "dependencies": "f4 mutates t but never assigns its function result; FortAD emits malformed parser, forward, and reverse interfaces",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-strict-compile-with-undefined-result-warning",
            },
            "todoF90/REFERENCES/v425": {
                "entry_point": "m.addvector(a,b,c)",
                "tapenade_options": "Options=-association byaddress|-p|-d|-b-root-addvector",
                "modes": "parser|forward|reverse",
                "oracle": "strict compiler|fresh pinned Tapenade parser/tangent/reverse generation and strict compilation|FortAD exact parser/forward/reverse refusal diagnostic|independent projection hand JVP/VJP|central-difference sweep|adjoint identity|upstream-source SHA-256 contract",
                "dependencies": "exact source has an uninitialized fichier path and FortAD stops at the module boundary; no bounded port claims whole-procedure semantics",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v426": {
                "entry_point": "head()",
                "tapenade_options": "-association byaddress|-vars inputs|-outvars outputs|-context|-noisize|-root head",
                "modes": "parser|forward|reverse",
                "oracle": "independent allocation-lifecycle model|hand JVP checked by central differences|hand VJP checked by adjoint identity|pinned-source SHA-256 contract",
                "dependencies": "exact allocated arrays and saved allocation lifecycle are unsupported; replacing them with fixed storage changes the case",
                "tapenade_result": "pass-fresh-Tapenade-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v427": {
                "entry_point": "m.setupData(dim)",
                "tapenade_options": "-association byaddress|-p|-d|-b-root-setupData",
                "modes": "parser|forward|reverse",
                "oracle": "strict gfortran compiler|fresh pinned Tapenade generation and strict compilation where a source is emitted|FortAD exact parser/forward/reverse diagnostic and no-output boundary|independent allocation-state semantic oracle|pinned source SHA-256 contract",
                "dependencies": "the procedure has only allocatable module state and no active numeric input or output",
                "tapenade_result": "pass-fresh-parser-generation-strict-compile-tangent-reverse-no-active-output",
            },
            "todoF90/REFERENCES/v469": {
                "entry_point": "head(x,y); port v469_head(x,y)",
                "tapenade_options": "-association byaddress|-vars x|-outvars y|-nooptim diffmodules|-p|-d|-b-root-head",
                "modes": "parser|forward|reverse",
                "oracle": "strict-gfortran exact-source and stored-reference boundary|fresh pinned Tapenade parser/tangent/reverse generation and strict compilation|FortAD exact parser/forward/reverse generation and strict compilation|bounded one-element port with explicit finite-real domain|independent sin-map central-difference JVP and VJP adjoint identity|upstream-source SHA-256 contract",
                "dependencies": "exact source retains a strict tab diagnostic; bounded port standardizes source form and claims only one-element finite real arrays",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile",
            },
            "todoF90/REFERENCES/v500": {
                "entry_point": "nl_model_mie_orig(alpha_ext,PP)",
                "tapenade_options": "Options=-nooptim nostatictape|-association byaddress|-p|-d|-b-root-nl_model_mie_orig",
                "modes": "parser|forward|reverse",
                "oracle": "strict compiler boundary|fresh pinned Tapenade generation and strict compilation|FortAD exact parser/forward/reverse refusal|independent alpha_ext hand model|central-difference JVP sweep|hand VJP adjoint identity|singular PP normalization semantic check|upstream-source SHA-256 contract",
                "dependencies": "FortAD rejects DATA and PP normalization remains singular because sigma_sca is zero; no repair is claimed",
                "tapenade_result": "pass-fresh-parser-tangent-strict-compile-reverse-strict-compile-refusal",
            },
            "nonRegressions/set01/lh070": {
                "entry_point": "top(A,B); F(); port set01_lh070(a,b,x,y,z)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|compiled-FortAD-harness",
                "dependencies": "exact routine carries x, y, and z in COMMON /cc/; program_dv.f requires absent DIFFSIZES.inc; bounded port exposes that state and checks final-y reverse",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set01/lh007": {
                "entry_point": "adj3(z,t); sub1(u,y2,z,v); port set01_lh007(z,t,x5,x8,x10,y,u,v,...)",
                "tapenade_options": "-p|-d-root-adj3|-b-root-adj3",
                "modes": "forward|reverse:t_out",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "exact source uses COMMON /cc/ and reads uninitialized local U/V; bounded port makes storage projection and initial values explicit",
                "tapenade_result": "pass-exact-and-fresh-generated-strict-compile",
            },
            "nonRegressions/set01/lh011": {
                "entry_point": "s1(a,b)",
                "tapenade_options": "-p|-d-root-s1|-b-root-s1",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|bounded-hand-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "uninitialized computed-GOTO selector; absent alternate-return callees TOTO/TUTU",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh017": {
                "entry_point": "test(a1,a2,b1,b2); port set01_lh017(a1,a2,branch,b1,b2)",
                "tapenade_options": "none",
                "modes": "forward|reverse:b1|reverse:b2",
                "oracle": "strict-compiler|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "implicit branch state made explicit",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generated-compile",
            },
            "nonRegressions/set01/lh022": {
                "entry_point": "test(x,y); port set01_lh022(x,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh028": {
                "entry_point": "s1(a,b); port set01_lh028(a,b)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-reverse-compile-rejection-integer4",
            },
            "nonRegressions/set01/lh023": {
                "entry_point": "test(a,b,c); port set01_lh023(a,b,c)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh032": {
                "entry_point": "sub1(x,y); port set01_lh032(x,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh049": {
                "entry_point": "sub0(x,y,z); port set01_lh049(x,y,z)",
                "tapenade_options": "none",
                "modes": "forward|reverse:z",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh134": {
                "entry_point": "toto(x,f); port set01_lh134(x,f)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh066": {
                "entry_point": "testSimplif(a,b); exact port set01_lh066_refusal(a,b)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "gfortran-compile-rejection",
                "dependencies": "none",
                "tapenade_result": "stored-d-reference-not-rerun",
            },
            "nonRegressions/set01/lh088": {
                "entry_point": "nondiff(a,b,c,d); port set01_lh088(a,b,c,d,total)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/bd06": {
                "entry_point": "toto(a,b)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|FortAD-diagnostic",
                "dependencies": "DIFFSIZES.inc-for-reference",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh057": {
                "entry_point": "test(a,b,c); port set01_lh057_split(a,b,c,a_out,c_out)",
                "tapenade_options": "none",
                "modes": "forward|reverse:a_out|reverse:c_out",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh058": {
                "entry_point": "ff(t,u,n,e); port set01_lh058(t,u,n,e)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh068": {
                "entry_point": "stmtfunc(a,b,c); port set01_lh068_split(a,b,c,c3,c7)",
                "tapenade_options": "none",
                "modes": "forward|reverse:c3|reverse:c7",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none; split outputs c3,c7 for in-place upstream update",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh001": {
                "entry_point": "top(i1,i2,i3,o1,o2,o3); port set01_lh001(i1,i2,i3,o1,o2,o3)",
                "tapenade_options": "none",
                "modes": "forward|reverse:o1",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "todoF90/REFERENCES/v420": {
                "entry_point": "g(u,v); port v420(u,v)",
                "tapenade_options": "-association byaddress",
                "modes": "forward|reverse",
                "oracle": "hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-parser-and-generated-compile",
            },
            "nonRegressions/set12/f03typf01": {
                "entry_point": "foo(t,x,y); port evaluate_deferred(model,x)",
                "tapenade_options": "-p program.f90; derivative probe records malformed generated source",
                "modes": "forward",
                "oracle": "strict-upstream-compile|generated-source-compile-rejection|concrete-child-values|central-difference-sweep",
                "dependencies": "none",
                "tapenade_result": "generated-source-compile-rejection",
            },
            "nonRegressions/set01/lh136": {
                "entry_point": "eval_f(x,y)",
                "tapenade_options": "-p|-d/-root-eval_f|-b/-root-eval_f",
                "modes": "parser|forward|reverse",
                "oracle": "strict-source-compile|fresh-Tapenade-parser-forward-reverse-generation|independent-hand-primal-central-difference-sweep",
                "dependencies": "legacy fixed-form main program, console I/O, and DIFFSIZES.inc",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile",
            },
            "nonRegressions/set01/lh144": {
                "entry_point": "top(x,y)",
                "tapenade_options": "-p/-root-top|-d/-root-top|-b/-root-top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-source-compile|fresh-Tapenade-parser-forward-reverse-generation|independent-hand-primal-central-difference-sweep-adjoint-identity",
                "dependencies": "local FOO call chain; no external dependency",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile",
            },
            "nonRegressions/set02/lh192": {
                "entry_point": "test(x,y,pkz)",
                "tapenade_options": "-p/-root-test|-d/-root-test|-b/-root-test",
                "modes": "parser|forward|reverse",
                "oracle": "strict-source-compile|fresh-Tapenade-parser-forward-reverse-generation|independent-hand-primal-central-difference-sweep",
                "dependencies": "large checkpoint loop over a 400^3 array",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile",
            },
            "nonRegressions/set02/lh196": {
                "entry_point": "POLYCOST(X,Y,ns)",
                "tapenade_options": "-p/-head-polycost|-d/-head-polycost|-b/-head-polycost",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-check-forward-reverse-inlining-diagnostic|independent-polygon-cost-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "REAL*8 strict boundary; POLYPERIM/INCRSQRT function-call inlining boundary; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-REAL8-refusal-legacy-compile-pass",
            },
            "nonRegressions/set02/lh198": {
                "entry_point": "top(x,y)",
                "tapenade_options": "-p/-root-top|-d/-root-top|-b/-root-top;Options=-context-nooptim-stripPrimalCode",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-check-forward-reverse-diagnostic|independent-COMMON-block-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "COMMON /comG/ aliases v4 and v6 across BBB, CCC, and internal DDD; no missing dependency; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-and-legacy-compile-pass",
            },
            "nonRegressions/set12/cmplxstep01": {
                "entry_point": "ff1(a,b,c)>(ff1)",
                "tapenade_options": "-p|-d|-b",
                "modes": "parser|forward|reverse",
                "oracle": "strict-source-compile|fresh-Tapenade-parser-forward-reverse-generation|independent-pure-subexpression-JVP-VJP",
                "dependencies": "active module variables and mutable derived-type component cross the differentiated call boundary",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-source-compile",
            },
            "nonRegressions/set12/f03fptr01": {
                "entry_point": "foo(i,x,y)",
                "tapenade_options": "-p|-d|-b",
                "modes": "parser|forward|reverse",
                "oracle": "strict-source-compile|fresh-Tapenade-parser-forward-reverse-generation|independent-procedure-selection-JVP-VJP",
                "dependencies": "abstract procedure interface and procedure-pointer aliasing",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-source-compile",
            },
            "nonRegressions/set12/jlb012": {
                "entry_point": "mysum(n,x); exact-source-only refusal",
                "tapenade_options": "-p|-d/-root-mysum|-b/-root-mysum",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-forward-reverse-generation|independent-hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile-refusal",
            },
            "nonRegressions/set12/profile01": {
                "entry_point": "foo(a,b,c); port set12_profile01(a,b,c)",
                "tapenade_options": "-p|-d/-root-foo|-b/-root-foo",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-forward-reverse-generation|independent-hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generated-strict-compile",
            },
            "nonRegressions/set02/lh163": {
                "entry_point": "test(v p q)>(v p q s); port test(v,p,q,s)",
                "tapenade_options": "-p/-root-test|-d/-root-test|-b/-root-test",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set02/v103": {
                "entry_point": "foo(x,y)",
                "tapenade_options": "-p|-d-root-foo|-b-root-foo",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-exact-check-forward-reverse-diagnostic|independent-linear-COMMON-state-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "exact COMMON /c/; no repaired port",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set02/v128": {
                "entry_point": "foo(n,x,y); exact source",
                "tapenade_options": "-p|-d-root-foo|-b-root-foo",
                "modes": "forward|reverse:y",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|compiled-FortAD-harness|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "local DIFFSIZES.inc only; no mixed-language dependency",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set02/v130": {
                "entry_point": "foo(x,y); exact source",
                "tapenade_options": "-p|-d-root-foo|-b-root-foo",
                "modes": "forward|reverse:y",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|compiled-FortAD-harness|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "local DIFFSIZES.inc only; no mixed-language dependency",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set03/ht05": {
                "entry_point": "toto(m,x,y)",
                "tapenade_options": "-p|-d/-root-toto|-b/-root-toto",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-refusal",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set03/ht06": {
                "entry_point": "titi(n,x,y)",
                "tapenade_options": "-p|-d/-root-titi|-b/-root-titi",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-refusal",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set03/ht12": {
                "entry_point": "top(a); toto(n,a)",
                "tapenade_options": "none",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-generated-compile-refusal",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set03/ht13": {
                "entry_point": "flx_blk(x,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse:y",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation|independent-hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set04/lh128": {
                "entry_point": "test(w)",
                "tapenade_options": "-p/-root-test|-d/-root-test|-b/-root-test",
                "modes": "forward|reverse:w",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|central-difference-JVP|FortAD-generated-reverse-compile-refusal",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set04/lh151": {
                "entry_point": "MUL(A,B,C)",
                "tapenade_options": "-p/-root-MUL|-d/-root-MUL|-b/-root-MUL",
                "modes": "forward|reverse:C",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand-complex-JVP|central-difference-JVP|FortAD-diagnostic",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set04/lh152": {
                "entry_point": "SATVAP(temp2,eval)",
                "tapenade_options": "-p/-root-SATVAP|-d/-root-SATVAP|-b/-root-SATVAP",
                "modes": "forward|reverse:eval",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|central-difference-sweep|reverse-adjoint-scalar",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set05/v150": {
                "entry_point": "f(t); port set05_v150(t,f)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set05/v168": {
                "entry_point": "test(x,y); port set05_v168(x,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set06/v314": {
                "entry_point": "test1(x,y,z); port set06_v314(x,y,z)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set06/v379": {
                "entry_point": "subr(n,x,f); port set06_v379(n,x,f)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh002": {
                "entry_point": "top(x,y,z,a,b,c); port set01_lh002(x_initial,z_initial,b_initial,x_final,y_final,z_final,a_final)",
                "tapenade_options": "none",
                "modes": "forward|reverse:x_final",
                "oracle": "strict-compiler|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "stored-d-b-references-not-rerun",
            },
            "nonRegressions/set01/lh003": {
                "entry_point": "adj2(x,y,z,N,o)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-source-inspection|safe-trace-hand-tangent|central-difference-sweep",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh012": {
                "entry_point": "test(A,B,C)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|safe-index-hand-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "INDX-uninitialized-local",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generated-compile",
            },
            "nonRegressions/set01/lh013": {
                "entry_point": "test(x,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|initialization-safe-hand-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "A(2)-read-before-initialization",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generated-compile",
            },
            "nonRegressions/set01/lh014": {
                "entry_point": "test(X,Y,p,q)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand-JVP-VJP|central-difference-sweep|adjoint-identity",
                "dependencies": "implicit-loop-index-i",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generated-compile",
            },
            "nonRegressions/set01/bd01": {
                "entry_point": "titi(w,x,y,z); port set01_bd01(x_initial,y_initial,z_initial,w_final,x_final,y_final,z_final)",
                "tapenade_options": "none",
                "modes": "forward|reverse:w_final",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-adjoint-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/bd02": {
                "entry_point": "toto(a,b); titi(a,b); port set01_bd02(b,a)",
                "tapenade_options": "none",
                "modes": "forward|reverse:a",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-adjoint-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/bd03": {
                "entry_point": "g(a,b); f(a,b); port set01_bd03(b,a)",
                "tapenade_options": "none",
                "modes": "forward|reverse:a",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-adjoint-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh005": {
                "entry_point": "adj4(y)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-source-inspection|branch-hand-derivative|central-difference-sweep",
                "dependencies": "COMMON blocks and unit I/O",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh006": {
                "entry_point": "adj6(x,y,z)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-source-inspection|fixed-trace-hand-derivative|central-difference-sweep",
                "dependencies": "external file donnees and COMMON block donnees",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile-refusal",
            },
            "nonRegressions/set01/lh019": {
                "entry_point": "top(x,y,n,*); port set01_lh019(x,y,n,output)",
                "tapenade_options": "associationByAddress references",
                "modes": "forward|reverse:output",
                "oracle": "strict-compiler|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none for port; upstream AATypes modules",
                "tapenade_result": "stored-aad-aab-references-compiled",
            },
            "nonRegressions/set01/lh004": {
                "entry_point": "tata(y,z,x); port set01_lh004(y_initial,z_initial,x1_final,x2_final)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|forward-transform|primal|hand|central-difference-sweep|FortAD-diagnostic",
                "dependencies": "none",
                "tapenade_result": "stored-d-reference-not-rerun",
            },
            "nonRegressions/set01/lh008": {
                "entry_point": "adjBlock1(x,y,z); port set01_lh008(y,x,z,objective)",
                "tapenade_options": "none",
                "modes": "forward|reverse:objective",
                "oracle": "strict-compiler|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-parser-and-generated-compile",
            },
            "nonRegressions/set01/lh010": {
                "entry_point": "toto(x); port set01_lh010(x,total)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-transform-compile",
            },
            "ADFirstAidKit/testMemSizef.f": {
                "entry_point": "program testmemsize",
                "tapenade_options": "-root testmemsize",
                "modes": "forward|reverse",
                "oracle": "upstream-runtime|Tapenade-parser-roundtrip|Fortran-storage_size|exact-engine-diagnostics",
                "dependencies": "ADFirstAidKit/testMemSizec.c",
                "tapenade_result": "refused-no-active-input-or-output",
            },
            "ADFirstAidKit/validityTest.f": {
                "entry_point": "validity_domain_real8(t,td)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|interval-state-transitions|FortAD-diagnostic",
                "dependencies": "none",
                "tapenade_result": "pass-transform-compile",
            },
            "nonRegressions/set01/lh016": {
                "entry_point": "ctest(in,out); port set01_lh016(input,output)",
                "tapenade_options": "-root ctest",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|Tapenade-generated-compile|hand-real-coordinate-JVP-VJP|central-difference-sweep|adjoint-identity|FortAD-diagnostic",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-forward-reverse-generated-compile",
            },
            "nonRegressions/set01/lh033": {
                "entry_point": "absorbN(data,resu,iz)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation-generated-compile|strict-source-refusal|central-difference-sweep",
                "dependencies": "COMMON block /ccc/",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh039": {
                "entry_point": "top(i1,i2,i3,o1,o2,o3); port set01_lh039(i1,i2,i3,o1,o2,o3)",
                "tapenade_options": "none",
                "modes": "forward|reverse:o1",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation-generated-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh040": {
                "entry_point": "f(t)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation-generated-compile|strict-source-refusal|central-difference-sweep",
                "dependencies": "fixed-form CHARACTER*10 declaration",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh074": {
                "entry_point": "fexchem(a,b,chem); port set01_lh074(a,b,chem)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "obsolete-RETURN-statement",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh080": {
                "entry_point": "sub1(a,b); port set01_lh080(a,b)",
                "tapenade_options": "none",
                "modes": "forward|reverse:b",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh082": {
                "entry_point": "alias(A,n,x); bounded port set01_lh082(a,n,x)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep",
                "dependencies": "undefined-upstream-array-elements",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh081": {
                "entry_point": "test2(a,f,jac,pjac)",
                "tapenade_options": "-p-root-test2|-d-root-test2|-b-root-test2",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-source|call-graph-oracle",
                "dependencies": "external f/jac/pjac procedures; implicit legacy state; absent DIFFSIZES.inc",
                "tapenade_result": "fresh-parser-tangent-reverse-generation-strict-pass-multidirectional-missing-include",
            },
            "nonRegressions/set01/lh083": {
                "entry_point": "aa(X,Y), calling modify(n)",
                "tapenade_options": "Tapenade-parser:-p|Tapenade-forward:-d-root-aa|Tapenade-reverse:-b-root-aa",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-fresh-Tapenade-compile|execution-prefix-oracle|FortAD-check-jvp-vjp",
                "dependencies": "exact trace reaches X(157) outside X(100); reverse needs per-iteration storage",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile",
            },
            "nonRegressions/set01/lh084": {
                "entry_point": "flw2d1col(nsg1,nsg2,nubo,t3,pres,vnocl,g3,g4,rh3,rh4,ns,nseg,sq)",
                "tapenade_options": "-p|-d|-b",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-generation|stored-adjoint-equivalence|finite-difference|adjoint-identity",
                "dependencies": "legacy labeled DO; strict REAL*8; absent DIFFSIZES.inc",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-generated-legacy-compile",
            },
            "nonRegressions/set01/lh087": {
                "entry_point": "nl_model_mie(pp,phase,number,sigma)",
                "tapenade_options": "-p-root-nl_model_mie|-d-root-nl_model_mie|-b-root-nl_model_mie",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|source-index-domain-oracle|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-warning-gate",
                "dependencies": "phase(10) and pp1(10,20) are indexed by j=1..20; absent DIFFSIZES.inc; no INTENT for pp",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set01/lh090": {
                "entry_point": "testInitAdj(x,y)",
                "tapenade_options": "-p|-d-root-testInitAdj|-b-root-testInitAdj",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation|finite-prefix-tangent|finite-prefix-adjoint|FortAD-diagnostic",
                "dependencies": "positive-input legacy GOTO loop does not terminate; absent DIFFSIZES.inc",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile",
            },
            "nonRegressions/set01/B01": {
                "entry_point": "gradfb(x,y,z,b,c,d,vol6)",
                "tapenade_options": "-p|-d/-root-gradfb|-b/-root-gradfb",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-forward-reverse-legacy-do-diagnostic|independent-determinant-volume-JVP-VJP-oracle",
                "dependencies": "legacy fixed-form and include context; exact-source-only",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-refusal-legacy-compile-pass",
            },
            "nonRegressions/set01/B03": {
                "entry_point": "viscflux(npdes,ewt,ubn,nl,beta,xi1,qi1,xdoti1,qli1,qpi1,disti1,epst,xi2,qi2,xdoti2,qli2,qpi2,disti2,vres6,fn,second_order)",
                "tapenade_options": "-p/-root-viscflux|-d/-root-viscflux|-b/-root-viscflux",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-forward-reverse-common-diagnostic|independent-viscous-flux-JVP-VJP-oracle",
                "dependencies": "COMMON /files/ at line 33 plus external LOW call; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-refusal-legacy-compile-pass",
            },
            "nonRegressions/set01/ala03": {
                "entry_point": "wave_resolution(id,p,n_global,n_local,nsteps,c,u_global)",
                "tapenade_options": "-head-wave_resolution(u_global)/(c)-noisize",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-check-forward-reverse-external-update-diagnostic|independent-wave-JVP-VJP-oracle",
                "dependencies": "MPI/update/collect external calls and MPI include context; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-parser-MPI-mismatch-forward-strict-pass-reverse-INTEGER4-refusal-legacy-pass",
            },
            "nonRegressions/set01/ala00": {
                "entry_point": "root(x,y,initial)",
                "tapenade_options": "-p/-root-root|-d/-root-root|-b/-root-root",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-forward-reverse-diagnostic|independent-fixed-point-JVP-VJP-oracle",
                "dependencies": "PRINT at line 39 is unsupported; stored and fresh reverse references have a strict REAL*8 boundary; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-forward-generation-strict-legacy-reverse-legacy-pass",
            },
            "nonRegressions/set01/ala01": {
                "entry_point": "root(x,y,initial)",
                "tapenade_options": "-p/-context/-root-root|-d/-context/-root-root|-b/-context/-root-root",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-parser-forward-reverse-diagnostic|independent-fixed-point-JVP-VJP-oracle",
                "dependencies": "PRINT at line 39 is unsupported; reverse REAL*8 is strict-refused; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-fresh-forward-matches-stored-fresh-reverse-matches-stored-strict-REAL8-refusal-legacy-pass",
            },
            "nonRegressions/set01/ala02": {
                "entry_point": "root(x,y,initial)",
                "tapenade_options": "-p|-d/-root-root|-b/-root-root",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-parser-forward-reverse-diagnostic|independent-fixed-point-JVP-VJP-oracle",
                "dependencies": "the exact source has PRINT at line 39 and an implicit REAL-to-INTEGER actual/dummy mismatch; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-parser-forward-strict-legacy-reverse-strict-refusal-legacy-pass",
            },
            "nonRegressions/set01/ala04": {
                "entry_point": "FP2(x,y)",
                "tapenade_options": "-p/-context|-d/-context|-b/-context",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-forward-reverse-diagnostic|independent-nested-fixed-point-JVP-VJP-oracle",
                "dependencies": "REAL*8 strict boundary and FortAD undeclared-name diagnostics; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-REAL8-refusal-legacy-pass",
            },
            "nonRegressions/set01/ala05": {
                "entry_point": "NFP(x,y)",
                "tapenade_options": "-head-NFP(y)/(x)-context-fixinterface",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-forward-reverse-DO-WHILE-diagnostic|independent-fixed-point-JVP-VJP-oracle",
                "dependencies": "DO WHILE line 27; reverse REAL*8 strict boundary; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-parser-forward-strict-legacy-reverse-REAL8-refusal-legacy-pass",
            },
            "nonRegressions/set01/bd04": {
                "entry_point": "toto(a)",
                "tapenade_options": "-p|-d-root-toto|-b-root-toto",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-parser-forward-reverse-print-diagnostic|independent-DO-control-JVP-VJP-oracle",
                "dependencies": "PRINT at line 26; exact fixed-form source only; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile",
            },
            "nonRegressions/set01/ht02": {
                "entry_point": "top(a)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-forward-reverse-diagnostic|independent-fixed-read-value-JVP-VJP-oracle",
                "dependencies": "top reads x from an external unit after myopen opens that unit; the exact source therefore has an unsupported external I/O boundary; no synthetic I/O value or repaired port is claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-legacy-compile",
            },
            "nonRegressions/set01/ht03": {
                "entry_point": "top(i1,i2,i3,o1,o2,o3); sub1(i1,i2,o1,o2)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-check-call-and-I-O-refusal|independent-conditional-read-value-JVP-VJP-oracle",
                "dependencies": "sub1 opens and reads external file toto; top's active call has no FortAD derivative rule; no repaired port is claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-and-legacy-compile",
            },
            "nonRegressions/set01/lh104": {
                "entry_point": "top(a,b,c,d)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-forward-reverse-diagnostic|independent-branch-jvp-vjp-oracle",
                "dependencies": "exact source modifies all four dummy arguments; stored reverse uses INTEGER*4 and implicit PUSHCONTROL1B/POPCONTROL1B; FortAD reverse assigns to d_b declared INTENT(IN)",
                "tapenade_result": "pass-fresh-Tapenade-parser-forward-reverse-generation-legacy-compile-strict-refusal",
            },
            "nonRegressions/set01/lh105": {
                "entry_point": "top(a,b,i)",
                "tapenade_options": "-p|-d-root-top|-b-root-top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-forward-reverse-codegen-boundary|independent-indexed-JVP-VJP-oracle",
                "dependencies": "inout array a is indexed before i is overwritten; i is a discrete control excluded from the real derivative; exact dependent a is also active input and FortAD reverse emits duplicate a_b formals; no repaired or synthetic port",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-and-legacy-compile",
            },
            "nonRegressions/set01/lh107": {
                "entry_point": "test(a,b)",
                "tapenade_options": "-p|-d-root-test|-b-root-test",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-exact-check-jvp-vjp|independent-max-sequence-jvp-vjp-oracle",
                "dependencies": "Tapenade's fresh forward reference has an unresolved MAX_D; FortAD direct products compile strictly for the exact source without a custom rule or repaired port",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-parser-strict-pass-forward-compiler-refusal-MAX_D-reverse-strict-refusal-legacy-pass",
            },
            "nonRegressions/set01/lh109": {
                "entry_point": "adj3(z,t); calls sub1(u,y2,z,v)",
                "tapenade_options": "-p|-d-root-adj3|-b-root-adj3",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-parser-forward-reverse-diagnostic|independent-bounded-sub1-jvp-vjp-oracle",
                "dependencies": "COMMON /cc/x,y unsupported at FortAD line 6; exact source has type-mismatched/aliased call and uninitialized u,v,j; no repaired port claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-legacy-compile-fresh-reverse-matches-stored-diagnostics-match-after-normalization",
            },
            "nonRegressions/set01/lh093": {
                "entry_point": "testIOmess(a,b,c,d,e)",
                "tapenade_options": "-p|-d-root-testIOmess|-b-root-testIOmess",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-parser-forward-reverse-diagnostic|independent-I/O-boundary-oracle",
                "dependencies": "interactive I/O and unsupported READ/WRITE statements are part of the exact procedure",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-legacy-compile-strict-refusal",
            },
            "nonRegressions/set01/lh094": {
                "entry_point": "test(a,b)",
                "tapenade_options": "-p|-d-root-test|-b-root-test|-ext-MyGeneralLib",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-parser-forward-reverse-diagnostic|independent-summary-boundary-oracle",
                "dependencies": "DISACTIVATE is supplied only by Tapenade's external summary; no FortAD rule or repaired port is claimed",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set01/lh097": {
                "entry_point": "testiotbr(a,b,c)",
                "tapenade_options": "-p|-d-root-testiotbr|-b-root-testiotbr",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-parser-forward-reverse-diagnostic|independent-fixed-read-value-oracle",
                "dependencies": "external I/O overwrites an active dummy and the exact source has a legacy I/O boundary",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-legacy-compile-strict-refusal",
            },
            "nonRegressions/set01/lh098": {
                "entry_point": "ff(N,t,xbt,x)",
                "tapenade_options": "-p|-d|-b",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-exact-jvp-vjp|independent-analytic-jvp-vjp-oracle",
                "dependencies": "the exact source and generated products depend on external CNKLOG/COMMON support; no repaired port is claimed",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile",
            },
            "nonRegressions/set01/lh102": {
                "entry_point": "testprotect(xx,yy,zz,vv1,vv2,vv3)",
                "tapenade_options": "-p|-d-root-testprotect|-b-root-testprotect",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-check-jvp-vjp|independent-three-case-semantic-oracle",
                "dependencies": "FortAD emits compilable derivatives but the exact protected-expression path is incomplete; no repaired port is claimed",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile",
            },
            "nonRegressions/set01/lh103": {
                "entry_point": "h(a,b,c,r)",
                "tapenade_options": "-p|-d|-b",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-tangent-reverse-generation|FortAD-check-jvp|independent-jvp-vjp-oracle",
                "dependencies": "reverse mode requires per-iteration storage that the current exact-source transformer does not provide",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile",
            },
            "nonRegressions/set01/lh089": {
                "entry_point": "pushpop(a,b)",
                "tapenade_options": "-p-root-pushpop|-d-root-pushpop-ext-PUSHPOPGeneralLib|-b-root-pushpop-ext-PUSHPOPGeneralLib",
                "modes": "parser|forward|reverse",
                "oracle": "strict-versus-legacy-compiler|fresh-Tapenade-generation|pushpop-state-machine|finite-difference|adjoint-identity|FortAD-diagnostic",
                "dependencies": "external PUSHREAL8/POPREAL8 summary; legacy REAL*8; active dummy declarations are not retained by current normalization",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-legacy-compile; expected-strict-REAL*8-refusal",
            },
            "nonRegressions/set01/lh085": {
                "entry_point": "bigexpr(flur1,fltr1,aux1,dpex,e2,dpm,aux2,dpor,r1,r2,v,v3,v6); port set01_lh085(flur1,fltr1,aux1,dpex,e2,dpm,aux2,dpor,r1,r2,v,v3,v6)",
                "tapenade_options": "none",
                "modes": "forward|reverse:r1",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "active input is v; scalar dependent is r1",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh092": {
                "entry_point": "f1(a,b,c); port set01_lh092(a,b,c)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "inline of nested f2 body",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh086": {
                "entry_point": "newton(x,n,alpha); port set01_lh086(x,n,alpha,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse:y",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "upstream x is inout; bounded port exposes final iterate y",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/lh018": {
                "entry_point": "top(a,b,c,d); f(u,v); port set01_lh018(b,c,a_out)",
                "tapenade_options": "none",
                "modes": "forward|reverse:a_out",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "bounded port makes dead second-function-argument mutation passive",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set01/bd05": {
                "entry_point": "head(a,b,c); leaf(a,b,c); port set01_bd05(a_in,b_in,c_in,a_out,c_out)",
                "tapenade_options": "none",
                "modes": "forward|reverse:a_out|reverse:c_out",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "bounded port declares legacy loop index and exposes mutated A/C outputs",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set02/lh150": {
                "entry_point": "top(xx); port set02_lh150(x,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse:y",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set03/ht09": {
                "entry_point": "fofo(x,y); port fofo(x,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse:y",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set04/lh110": {
                "entry_point": "foo(x,y); port set04_lh110(x,y)",
                "tapenade_options": "none",
                "modes": "forward|reverse:y",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "bounded port preserves the active storage/dataflow chain with explicit lifetime",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set05/v052": {
                "entry_point": "test(x,i); port set05_v052(x,i)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set05/v125": {
                "entry_point": "surface(x1,x2,y1,y2,z); port set05_v125(x1,x2,y1,y2,z)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set05/v137": {
                "entry_point": "s(x,y); port set05_v137(x,y,s)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "nonRegressions/set06/v234": {
                "entry_point": "program TEST; contained function F(t); port set06_v234(t,f)",
                "tapenade_options": "none",
                "modes": "forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|hand|central-difference-sweep|adjoint-identity",
                "dependencies": "none",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "todoF90/REFERENCES/v504": {
                "entry_point": "top(r,s); compute(x,y); ftest(r,s,compute); port set01_v504(r,s,top)",
                "tapenade_options": "Options=-head top|-p/-d/-b-root-top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-exact-parser-forward-reverse-refusal|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|upstream-source-SHA-256-contract",
                "dependencies": "M/M1_I/M2_I modules; exact interface collision; bounded port excludes global and caller-visible s mutation",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile-refusal",
            },
            "todoF90/REFERENCES/v505": {
                "entry_point": "top(r,s); compute(x,y); port not-claimed",
                "tapenade_options": "-p/-d/-b-root-top",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-exact-parser-forward-reverse-refusal|independent-callback-graph-and-shape-semantic-oracle|upstream-source-SHA-256-contract",
                "dependencies": "external ftest and compute implementations absent; stored forward only; no reverse reference",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-compile",
            },
            "todoF90/REFERENCES/v508": {
                "entry_point": "top(r,s); compute(x,y)",
                "tapenade_options": "-head top -head compute|-p/-d/-b",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-exact-parser-forward-reverse-codegen-boundary|independent-closed-form-JVP-VJP|central-difference-sweep|adjoint-identity|inout-global-state-semantic-check|upstream-source-SHA-256-contract",
                "dependencies": "external compute/ftest interfaces; inout s and global state; exact generated code boundary",
                "tapenade_result": "pass-fresh-parser-tangent-strict-compile-reverse-strict-compile-refusal",
            },
            "todoF90/REFERENCES/v519": {
                "entry_point": "PROGRAM TEST_IT",
                "tapenade_options": "-p/-d/-b-root-TEST_IT",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler-boundary|fresh-Tapenade-parser-generation|FortAD-exact-parser-forward-reverse-refusal|independent-record-shape-semantic-oracle|upstream-source-SHA-256-contract",
                "dependencies": "standalone PROGRAM has no callable procedure interface; no bounded port",
                "tapenade_result": "generation-success-strict-compile-refusal-parser-forward-reverse",
            },
            "todoF90/REFERENCES/v526": {
                "entry_point": "SING3(DXP,DYP,Epaisseur_Seuil); port v526_sing3(dxp,dyp_initial,epaisseur_seuil)",
                "tapenade_options": "-p/-d/-b-root-SING3",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-exact-parser-forward-reverse-refusal|independent-SING3-hand-JVP-VJP|central-difference-sweep|adjoint-identity|upstream-source-SHA-256-contract",
                "dependencies": "FoX/module bundle lacks fox_dom.mod and exact source has undefined dp/sp and ambiguous generic; bounded one-element port",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile-refusal",
            },
            "todoF90/REFERENCES/v547": {
                "entry_point": "endval(bb,aind,bind,cind,n); xmul; xadd; xdot",
                "tapenade_options": "-head endval(endval)/(bb)|-p/-d/-b",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-exact-parser-forward-reverse-refusal|independent-indexed-array-JVP-VJP|central-difference-sweep|adjoint-identity|upstream-source-SHA-256-contract",
                "dependencies": "COMMON state; stored/fresh derivative references retain legacy kind/declaration defects; no repaired port",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-strict-compile-refusal",
            },
            "nonRegressions/set01/lh000": {
                "entry_point": "none (empty program.f and program.f90)",
                "tapenade_options": "-p|-d|-b (no root; empty source)",
                "modes": "parser|forward|reverse",
                "oracle": "independent-empty-source-and-refusal-semantics|strict-compiler|fresh-pinned-Tapenade-generation|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "empty source; stored messages only; no entry point",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-no-entry",
            },
            "nonRegressions/set02/v065": {
                "entry_point": "none (BLOCKDATA /axes/)",
                "tapenade_options": "-p|-d|-b (no root)",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-no-root|FortAD-exact-no-entry-boundary|independent-COMMON-state-oracle|upstream-source-SHA-256-contract",
                "dependencies": "BLOCKDATA initializes COMMON /axes/; parser reference only; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-tangent-reverse-no-root",
            },
            "nonRegressions/set04/v017": {
                "entry_point": "none (module Z only)",
                "tapenade_options": "-p|-d/-b-no-root",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-generation|independent-module-declaration-oracle|upstream-source-SHA-256-contract",
                "dependencies": "module-only source with COMMON /vars/; no executable unit or selected procedure",
                "tapenade_result": "parser-generated-strict-compile-refusal-tangent-reverse-no-root-messages",
            },
            "nonRegressions/set04/v025": {
                "entry_point": "none (modules A-E only)",
                "tapenade_options": "-p|-d/-b-no-root",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-no-root|independent-module-storage-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "declaration-only modules with saved state; no callable procedure or standalone program",
                "tapenade_result": "pass-fresh-parser-generation-strict-compile-tangent-reverse-no-root",
            },
            "nonRegressions/set05/v075": {
                "entry_point": "none (MODULE BLOCKS only)",
                "tapenade_options": "-p/-d/-b-no-root",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-parser-no-root|independent-type-layout-oracle|FortAD-exact-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module-only derived type and parser reference; no callable entry point",
                "tapenade_result": "pass-no-root-parser-reference-only-tangent-reverse-messages",
            },
            "nonRegressions/set05/v146": {
                "entry_point": "none (module A only)",
                "tapenade_options": "-p/-d/-b-root-A (module probe)",
                "modes": "parser|forward|reverse",
                "oracle": "strict-compiler|fresh-Tapenade-no-root|independent-module-and-entry-point-inventory|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module A has no procedure or program; parser reference only",
                "tapenade_result": "pass-fresh-parser-generation-no-root",
            },
            "nonRegressions/set05/v147": {
                "entry_point": "none (module A only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-module-entry-point-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module A declarations and derived type; no callable procedure",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-no-root",
            },
            "nonRegressions/set05/v171": {
                "entry_point": "none (module TEST only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-module-declaration-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module TEST declarations and initialized state; no callable procedure",
                "tapenade_result": "pass-fresh-no-root-parser-strict-compile-tangent-reverse-no-source",
            },
            "nonRegressions/set05/v177": {
                "entry_point": "none (module MCRM2PAR only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-module-parameter-array-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module-only parameter and array state; strict legacy declarations; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-refusal-tangent-reverse-no-root",
            },
            "nonRegressions/set05/v201": {
                "entry_point": "none (module TEST only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-module-array-layout-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module-only arrays and parameters; strict REAL*8 boundary; no callable procedure",
                "tapenade_result": "pass-no-root-parser-reference-only-tangent-reverse-messages",
            },
            "nonRegressions/set05/v216": {
                "entry_point": "none (modules DEFINITION and RK only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-module-use-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module USE dependency and private state; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-tangent-reverse-no-root",
            },
            "nonRegressions/set06/v316": {
                "entry_point": "none (module M only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-pointer-declaration-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module-only pointer declarations with invalid initialization; no callable procedure",
                "tapenade_result": "pass-generation-parser-strict-refusal-tangent-reverse-no-root-messages",
            },
            "nonRegressions/set06/v317": {
                "entry_point": "none (module M only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-pointer-null-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module-only NULL pointer declaration; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-tangent-reverse-no-root",
            },
            "nonRegressions/set06/v320": {
                "entry_point": "none (module TEST_TYPEDEF only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-derived-type-layout-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module-only data and derived types; no callable procedure",
                "tapenade_result": "pass-fresh-no-root-parser-strict-compile-tangent-reverse-no-source",
            },
            "nonRegressions/set01/lh091": {
                "entry_point": "bugequiv(c); FF(x)",
                "tapenade_options": "-p|-d-root-bugequiv|-b-root-bugequiv",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-source-first-and-compatibility-common-diagnostic|independent-FF-update-JVP-VJP-oracle",
                "dependencies": "legacy COMMON/EQUIVALENCE state and absent authoritative DIFFSIZES.inc; exact-source-only",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-and-legacy-compile",
            },
            "nonRegressions/set01/lh095": {
                "entry_point": "testliveness(a,b,c,d); SUB1(a,b)",
                "tapenade_options": "-p|-d-root-testliveness|-b-root-testliveness",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-source-first-and-compatibility-reverse-diagnostic|independent-liveness-JVP-VJP-oracle",
                "dependencies": "absent authoritative DIFFSIZES.inc; exact reverse reaches undeclared SUB1 result; exact-source-only",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile",
            },
            "nonRegressions/set01/lh096": {
                "entry_point": "testliveness(a,b,c,d); SUB1(a,b)",
                "tapenade_options": "-p|-d-root-testliveness|-b-root-testliveness",
                "modes": "parser|forward|reverse",
                "oracle": "strict-and-legacy-compiler|fresh-Tapenade-parser-forward-reverse-generation|FortAD-source-first-and-compatibility-reverse-diagnostic|independent-liveness-JVP-VJP-oracle",
                "dependencies": "absent authoritative DIFFSIZES.inc; exact source has undeclared SUB1 result boundary; exact-source-only",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-and-legacy-compile",
            },
            "nonRegressions/set06/v360": {
                "entry_point": "none (modules M0 and M1 only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-module-private-state-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module USE dependency and private state; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-tangent-reverse-no-root-no-source",
            },
            "nonRegressions/set06/v362": {
                "entry_point": "none (modules M0 and M1 only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-module-private-attribute-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module USE dependency with PRIVATE attributes; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-tangent-reverse-no-root",
            },
            "nonRegressions/set07/v485": {
                "entry_point": "none (module FOX_DOM_TYPES only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-private-derived-type-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module-only private pointer component; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-tangent-reverse-no-root-messages",
            },
            "nonRegressions/set07/v523": {
                "entry_point": "none (empty source)",
                "tapenade_options": "-p|-d|-b (no root unit; empty source)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-empty-source-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "empty source and stored message only; no callable procedure",
                "tapenade_result": "pass-empty-parser-message-tangent-reverse-no-root-messages",
            },
            "nonRegressions/set07/v544": {
                "entry_point": "none (module TEST only)",
                "tapenade_options": "-p|-d|-b (no root unit)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse|independent-private-type-layout-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module-only C_PTR declaration and parameter; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-tangent-reverse-no-root",
            },
            "nonRegressions/set11/vpf16": {
                "entry_point": "none (modules ESMF_CalendarMod and mo only)",
                "tapenade_options": "-p|-d|-b (no root unit; Options=-msginfile -noinclude -noisize)",
                "modes": "parser|forward:no-root|reverse:no-root",
                "oracle": "strict-compiler|Options-metadata|fresh-Tapenade-parser-tangent-reverse|independent-module-use-oracle|FortAD-no-entry-boundary|upstream-source-SHA-256-contract",
                "dependencies": "module USE dependency and PRIVATE declarations; no callable procedure",
                "tapenade_result": "pass-fresh-parser-strict-compile-tangent-reverse-no-root-messages",
            },
            "nonRegressions/set04/lh148": {
                "entry_point": "toto(a,b,c,d); exact source",
                "tapenade_options": "-p/-root-toto|-d/-root-toto|-b/-root-toto",
                "modes": "parser|forward|reverse:d",
                "oracle": "strict-compiler|fresh-Tapenade-parser-tangent-reverse-compile|FortAD-forward-reverse-transform-strict-compile|independent-hand-JVP-VJP|central-difference-sweep|adjoint-identity|upstream-source-SHA-256-contract",
                "dependencies": "same-file module1/module2/module3 source; no external dependency",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set05/v054": {
                "entry_point": "f_vector(x)",
                "tapenade_options": "-p/-root-f_vector|-d/-root-f_vector|-b/-root-f_vector",
                "modes": "parser|forward|reverse",
                "oracle": "exact-source strict compile|fresh pinned Tapenade parser-forward-reverse generation|FortAD exact module-extraction JVP-VJP strict compile-runtime|independent reciprocal vector hand-central-difference-adjoint oracle",
                "dependencies": "upstream module and driver; FortAD uses the exact f_vector module extraction",
                "tapenade_result": "pass-fresh-parser-forward-reverse-generation-strict-compile",
            },
            "nonRegressions/set05/v060": {
                "entry_point": "M::func(t,u)",
                "tapenade_options": "-p/-root-func|-d/-root-func|-b/-root-func",
                "modes": "parser|forward|reverse",
                "oracle": "exact-source-hashes|strict-exact-compile|fresh-Tapenade-parser-tangent-reverse-generation-strict-compile|FortAD-forward-reverse-transform-strict-compile-runtime|independent-hand-finite-difference-adjoint-oracle",
                "dependencies": "self-contained exact source; standards-clean stored module extraction",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set05/v061": {
                "entry_point": "M::func(t,u)",
                "tapenade_options": "-p/-root-func|-d/-root-func|-b/-root-func",
                "modes": "parser|forward|reverse",
                "oracle": "exact-source-hashes|strict-exact-compile|fresh-Tapenade-parser-tangent-reverse-generation-strict-compile|FortAD-forward-reverse-transform-strict-compile-runtime|independent-hand-finite-difference-adjoint-oracle",
                "dependencies": "self-contained M::func(t,u); callback modules N/O and program driver remain outside the selected closure",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set05/v062": {
                "entry_point": "M::func(t,u)",
                "tapenade_options": "-p/-root-func|-d/-root-func|-b/-root-func",
                "modes": "parser|forward|reverse",
                "oracle": "exact-source-hashes|strict-exact-compile|fresh-Tapenade-parser-tangent-reverse-generation-strict-compile|FortAD-forward-reverse-transform-strict-compile-runtime|independent-hand-finite-difference-adjoint-oracle",
                "dependencies": "exact program.f90 compiled unchanged; standards-clean selected M::func(t,u) extraction; N/O callbacks and program driver remain outside the FortAD derivative closure",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set05/v064": {
                "entry_point": "LIB::mppsum_real(ptab)",
                "tapenade_options": "-p/-root-mppsum_real|-d/-root-mppsum_real|-b/-root-mppsum_real",
                "modes": "parser|forward|reverse",
                "oracle": "exact-source-hashes|strict-exact-compile|fresh-Tapenade-parser-tangent-reverse-generation-strict-compile|FortAD-forward-reverse-transform-strict-compile-runtime|independent-hand-finite-difference-adjoint-oracle",
                "dependencies": "exact v064 source and stored references compiled unchanged; standards-clean selected value-map extraction of LIB::mppsum_real(ptab); generic caller remains outside derivative closure",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set05/v065": {
                "entry_point": "LIB::mppsum_real2(ptab,cst,str)",
                "tapenade_options": "-p/-root-mppsum_real2|-d/-root-mppsum_real2|-b/-root-mppsum_real2",
                "modes": "parser|forward|reverse",
                "oracle": "exact-source-hashes|strict-exact-compile|fresh-Tapenade-parser-tangent-reverse-generation-strict-compile|FortAD-forward-reverse-transform-strict-compile-runtime|independent-hand-finite-difference-adjoint-oracle",
                "dependencies": "exact v065 source and stored references compile unchanged; ptab is the active input and cst is passive in the selected value-map closure; generic caller and mppsum_real3 remain outside",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-generated-strict-compile",
            },
            "nonRegressions/set05/v067": {
                "entry_point": "RUN::s(mb1,mb2,mb3)",
                "tapenade_options": "-p/-root-s|-d/-root-s|-b/-root-s",
                "modes": "parser|forward|reverse",
                "oracle": "strict-exact-and-stored-compiler|legacy-control-compile|fresh-Tapenade-parser-tangent-reverse-generation-strict-and-legacy-compile|FortAD-exact-parser-forward-reverse-no-output|independent-source-compiler-oracle",
                "dependencies": "exact and stored sources use nonstandard REAL*8; standardizing it or changing the generic interface would be a source repair, so no repaired port is claimed",
                "tapenade_result": "pass-fresh-parser-tangent-reverse-generation-legacy-compile-strict-REAL8-refusal",
            },
        }
        evidence_columns = tuple(next(iter(expected_evidence.values())))
        for row in evidence:
            self.assertEqual(
                {column: row[column] for column in evidence_columns},
                expected_evidence[row["path"]],
            )
        self.assertEqual(
            {
                row["path"]: row["fortad_result"]
                for row in evidence
            }["nonRegressions/set01/lh066"],
            "refused-generated-reverse-does-not-compile",
        )
        self.assertEqual(
            {
                row["path"]: row["fortad_result"]
                for row in evidence
            }["nonRegressions/set01/bd06"],
            "unsupported-reverse-constant-loop",
        )
        self.assertEqual(
            Counter(row["language"] for row in rows),
            Counter({
                "fortran": 1432,
                "c": 445,
                "c|fortran": 72,
                "cuda": 35,
                "c++": 16,
                "julia": 10,
                "c++|fortran": 2,
                "unknown": 2,
            }),
        )
        self.assertEqual(
            Counter(row["source_form_hint"] for row in rows),
            Counter({"free": 1057, "n/a": 508, "fixed": 420, "mixed": 29}),
        )


class UpstreamPinAuditTests(unittest.TestCase):
    def test_pin_audit_distinguishes_metadata_floating_and_verified_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = CorpusFetchTests().make_source(root)
            entries = [
                {
                    "name": "metadata",
                    "url": "https://example.invalid/docs",
                    "ref": "web",
                    "license": "METADATA-ONLY (restricted source)",
                    "why": "source is restricted",
                },
                {
                    "name": "floating",
                    "url": source.as_uri(),
                    "ref": "main",
                    "license": "MIT",
                },
                {
                    "name": "pinned",
                    "url": source.as_uri(),
                    "ref": revision,
                    "license": "MIT",
                },
            ]
            destination = root / "upstream"
            with patch.object(fetch_upstreams, "DEST", destination):
                self.assertTrue(fetch_upstreams.clone(entries[2], depth=1))
                rows = fetch_upstreams.audit_upstream_pins(entries)

            self.assertEqual(
                [(row["name"], row["kind"], row["checkout"]) for row in rows],
                [
                    ("metadata", "metadata-only", "not-applicable"),
                    ("floating", "floating-ref", "not-fetched"),
                    ("pinned", "commit-pinned", "clean"),
                ],
            )
            pinned = rows[2]
            self.assertEqual(pinned["revision"], revision)
            self.assertEqual(pinned["tree"], tree)
            self.assertEqual(pinned["origin"], source.as_uri())
            report = fetch_upstreams.render_upstream_pin_audit(rows)
            self.assertIn("metadata-only", report)
            self.assertIn("floating-ref", report)
            self.assertIn(f"`{revision}`", report)
            self.assertIn(f"`{tree}`", report)
            self.assertIn("1 not-fetched checkouts", report)
            self.assertIn("Result: FAIL", report)

    def test_pin_audit_marks_modified_checkout_and_preserves_no_hash_claim(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, tree = CorpusFetchTests().make_source(root)
            entry = {
                "name": "pinned",
                "url": source.as_uri(),
                "ref": revision,
                "license": "MIT",
            }
            destination = root / "upstream"
            with patch.object(fetch_upstreams, "DEST", destination):
                self.assertTrue(fetch_upstreams.clone(entry, depth=1))
                (destination / "pinned" / "untracked.txt").write_text("dirty\n")
                row = fetch_upstreams.audit_upstream_pins([entry])[0]
            self.assertEqual(row["checkout"], "dirty")
            self.assertEqual(row["revision"], revision)
            self.assertEqual(row["tree"], tree)
            self.assertNotEqual(row["revision"], "n/a")
            self.assertNotIn("invented", fetch_upstreams.render_upstream_pin_audit([row]))

    def test_pin_audit_rejects_a_clean_checkout_at_the_wrong_commit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, revision, _tree = CorpusFetchTests().make_source(root)
            destination = root / "upstream"
            entry = {
                "name": "pinned",
                "url": source.as_uri(),
                "ref": "0" * 40,
                "license": "MIT",
            }
            with patch.object(fetch_upstreams, "DEST", destination):
                checkout = destination / "pinned"
                checkout.parent.mkdir(parents=True)
                subprocess.run(["git", "clone", "-q", source.as_uri(), str(checkout)], check=True)
                row = fetch_upstreams.audit_upstream_pins([entry])[0]
            self.assertEqual(row["revision"], revision)
            self.assertEqual(row["checkout"], "revision-mismatch")
            self.assertIn("Result: FAIL", fetch_upstreams.render_upstream_pin_audit([row]))


class CommittedTapenadeStaticTriageTests(unittest.TestCase):
    def test_committed_static_triage_covers_the_pinned_candidate_keys(self):
        root = Path(__file__).resolve().parent.parent
        with (root / "docs" / "corpora" / "tapenade.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        with (root / manifest["static_triage"]).open(encoding="utf-8") as stream:
            rows = [json.loads(line) for line in stream]
        with (root / manifest["status_ledger"]).open(
            encoding="utf-8", newline=""
        ) as stream:
            ledger = {
                (row["component"], row["path"]): row
                for row in csv.DictReader(stream)
            }

        self.assertEqual(len(rows), manifest["expected_candidate_cases"])
        keys = [(row["component"], row["path"]) for row in rows]
        self.assertEqual(len(set(keys)), 2014)
        self.assertEqual(set(keys), set(ledger))
        self.assertEqual({row["schema_version"] for row in rows}, {1})
        self.assertEqual(
            Counter(row["classification"] for row in rows),
            Counter({
                "fortran-procedure-candidate": 1081,
                "fortran-runnable-candidate": 330,
                "fortran-source-candidate": 21,
                "harness-reference-data": 2,
                "mixed-language-source": 74,
                "non-fortran-source": 506,
            }),
        )
        self.assertEqual(sum(len(row["source_files"]) for row in rows), 6078)
        self.assertEqual(sum(len(row["entry_point_hints"]) for row in rows), 12960)
        self.assertEqual(sum(len(row["include_hints"]) for row in rows), 2488)
        self.assertEqual(sum(len(row["use_hints"]) for row in rows), 2348)
        for row in rows:
            key = (row["component"], row["path"])
            self.assertEqual(row["language"], ledger[key]["language"])
            self.assertEqual(row["source_form_hint"], ledger[key]["source_form_hint"])
            self.assertTrue(
                all(
                    source == row["path"] or source.startswith(f"{row['path']}/")
                    for source in row["source_files"]
                )
            )
            self.assertTrue(
                all(
                    hint["source"] in row["source_files"]
                    for field in ("entry_point_hints", "include_hints", "use_hints")
                    for hint in row[field]
                )
            )
            self.assertFalse(
                {"status", "tapenade_result", "fortad_result"}.intersection(row)
            )


if __name__ == "__main__":
    unittest.main()
