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
            "nonRegressions/set01/lh001",
            "nonRegressions/set01/lh023",
            "nonRegressions/set01/lh032",
            "nonRegressions/set01/lh134",
            "nonRegressions/set01/lh066",
            "nonRegressions/set01/lh088",
            "nonRegressions/set01/bd06",
            "nonRegressions/set01/lh057",
            "nonRegressions/set01/lh058",
            "nonRegressions/set01/lh068",
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
        self.assertEqual({row["path"] for row in evidence}, evidence_paths)
        self.assertEqual(
            {row["status"] for row in evidence},
            {"runnable-ported", "expected-refusal"},
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
            },
        )
        expected_evidence = {
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
