#!/usr/bin/env python3
"""Behavioral checks for the study-corpus fetch and license inventory helpers."""

from pathlib import Path
import hashlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import sys

import fetch_upstreams


class LicenseInventoryTests(unittest.TestCase):
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
            "corpus/set01/case_a/program.f90": "subroutine a\nend subroutine a\n",
            "corpus/set01/case_b/program.c": "void b(void) {}\n",
            "aux/test.jl": "f(x) = x\n",
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

    def write_manifest(self, root: Path, source: Path, revision: str, tree: str) -> None:
        manifest = root / "docs" / "corpora" / "fixture.toml"
        manifest.parent.mkdir(parents=True)
        license_digest = hashlib.sha256(b"fixture license\n").hexdigest()
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
                (checkout / "untracked.f90").write_text("end\n")
                with self.assertRaisesRegex(fetch_upstreams.CorpusError, "checkout is modified"):
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


if __name__ == "__main__":
    unittest.main()
