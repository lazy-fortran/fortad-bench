#!/usr/bin/env python3
"""Fetch third-party AD projects into the gitignored upstream/ tree.

Read-only study copies. Nothing fetched here may be committed to fortad or
redistributed in any form. See LEGAL.md.

Usage:
    scripts/fetch_upstreams.py                 # fetch everything
    scripts/fetch_upstreams.py enzyme clad     # fetch selected entries
    scripts/fetch_upstreams.py --category julia
    scripts/fetch_upstreams.py --corpus tapenade
    scripts/fetch_upstreams.py --audit-corpora # no network
    scripts/fetch_upstreams.py --list
    scripts/fetch_upstreams.py --licenses      # re-scan checkouts, write inventory
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "docs" / "upstreams.toml"
DEST = ROOT / "upstream"
GENERATED = ROOT / "docs" / "generated"

# Entries whose `url` is not a git remote.
NON_GIT = {"web"}

LICENSE_NAMES = (
    "LICENSE", "LICENSE.txt", "LICENSE.md", "LICENCE", "LICENCE.txt",
    "COPYING", "COPYING.txt", "COPYING.LESSER", "LICENSE.TXT",
    "LICENSE-MIT", "LICENSE-APACHE", "NOTICE",
)
LICENSE_NAMES_CASEFOLD = {name.casefold() for name in LICENSE_NAMES}
GIT_TIMEOUT_SECONDS = 120
COMMIT_RE = re.compile(r"[0-9a-fA-F]{40}")


class CorpusError(RuntimeError):
    """The fetched checkout does not satisfy its committed corpus contract."""


def load() -> list[dict]:
    with MANIFEST.open("rb") as fh:
        return tomllib.load(fh)["upstream"]


def _git(target: Path, *args: str) -> str:
    rc = subprocess.run(
        ["git", "-C", str(target), *args],
        capture_output=True,
        text=True,
        timeout=GIT_TIMEOUT_SECONDS,
    )
    if rc.returncode != 0:
        detail = rc.stderr.strip() or rc.stdout.strip() or "git command failed"
        raise CorpusError(detail)
    return rc.stdout.strip()


def _clone_pinned_commit(url: str, ref: str, target: Path, depth: int) -> bool:
    """Fetch one advertised commit without downloading unrelated history."""
    DEST.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix=f".{target.name}-", dir=DEST) as directory:
            checkout = Path(directory) / "checkout"
            commands = (
                ["git", "init", "-q", str(checkout)],
                ["git", "-C", str(checkout), "remote", "add", "origin", url],
                ["git", "-C", str(checkout), "fetch", "--depth", str(depth), "origin", ref],
                ["git", "-C", str(checkout), "checkout", "-q", "--detach", "FETCH_HEAD"],
            )
            for command in commands:
                rc = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    timeout=GIT_TIMEOUT_SECONDS,
                )
                if rc.returncode != 0:
                    tail = (rc.stderr or rc.stdout).strip().splitlines()[-1:]
                    print(f"  FAIL   {target.name}: {tail}")
                    return False
            checkout.rename(target)
    except subprocess.TimeoutExpired:
        print(f"  FAIL   {target.name}: clone timed out after {GIT_TIMEOUT_SECONDS}s")
        return False
    return True


def clone(entry: dict, depth: int, jobs_note: str = "") -> bool:
    name, url, ref = entry["name"], entry["url"], entry["ref"]
    target = DEST / name

    if ref in NON_GIT:
        target.mkdir(parents=True, exist_ok=True)
        (target / "FETCH_NOTE.txt").write_text(
            f"{name}: not a git remote.\n"
            f"Documentation-only entry. Consult {url} in a browser.\n"
            "Do not copy source from registration-gated distributions.\n"
        )
        print(f"  note   {name}: documentation-only, see {url}")
        return True

    if target.exists():
        print(f"  update {name}")
        try:
            rc = subprocess.run(
                ["git", "-C", str(target), "fetch", "--depth", str(depth), "origin", ref],
                capture_output=True, text=True, timeout=GIT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            print(f"  WARN   {name}: fetch timed out after {GIT_TIMEOUT_SECONDS}s")
            return False
        if rc.returncode != 0:
            print(f"  WARN   {name}: fetch failed: {rc.stderr.strip().splitlines()[-1:]}")
            return False
        checked_out = subprocess.run(
            ["git", "-C", str(target), "checkout", "-q", "FETCH_HEAD"],
            check=False, timeout=GIT_TIMEOUT_SECONDS,
        )
        if checked_out.returncode != 0:
            print(f"  WARN   {name}: checkout of fetched revision failed")
            return False
        return True

    print(f"  clone  {name}  <- {url} @ {ref}")
    if COMMIT_RE.fullmatch(ref):
        return _clone_pinned_commit(url, ref, target, depth)
    try:
        rc = subprocess.run(
            ["git", "clone", "--depth", str(depth), "--branch", ref,
             "--single-branch", url, str(target)],
            capture_output=True, text=True, timeout=GIT_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        print(f"  FAIL   {name}: clone timed out after {GIT_TIMEOUT_SECONDS}s")
        return False
    if rc.returncode != 0:
        # Some refs are commit hashes, which --branch rejects.
        try:
            rc2 = subprocess.run(
                ["git", "clone", "--filter=blob:none", url, str(target)],
                capture_output=True, text=True, timeout=GIT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            print(f"  FAIL   {name}: fallback clone timed out after {GIT_TIMEOUT_SECONDS}s")
            return False
        if rc2.returncode != 0:
            tail = (rc.stderr or rc2.stderr).strip().splitlines()[-1:]
            print(f"  FAIL   {name}: {tail}")
            return False
        checked_out = subprocess.run(
            ["git", "-C", str(target), "checkout", "-q", ref],
            check=False, timeout=GIT_TIMEOUT_SECONDS,
        )
        if checked_out.returncode != 0:
            print(f"  FAIL   {name}: requested ref {ref!r} is unavailable")
            return False
    return True


def record_revision(entry: dict) -> str:
    target = DEST / entry["name"]
    rc = subprocess.run(["git", "-C", str(target), "rev-parse", "HEAD"],
                        capture_output=True, text=True)
    return rc.stdout.strip() if rc.returncode == 0 else "n/a"


def _load_corpus_manifest(entry: dict) -> dict:
    relative = entry.get("corpus_manifest")
    if not relative:
        raise CorpusError(f"{entry['name']} has no corpus_manifest")
    manifest = ROOT / relative
    if not manifest.is_file():
        raise CorpusError(f"missing corpus manifest: {relative}")
    with manifest.open("rb") as fh:
        corpus = tomllib.load(fh)
    if corpus.get("schema_version") != 1:
        raise CorpusError(f"unsupported corpus schema in {relative}")
    if corpus.get("upstream") != entry["name"]:
        raise CorpusError(f"{relative} names upstream {corpus.get('upstream')!r}")
    if corpus.get("origin") != entry["url"]:
        raise CorpusError(f"{relative} origin differs from docs/upstreams.toml")
    if corpus.get("revision") != entry["ref"]:
        raise CorpusError(f"{relative} revision differs from docs/upstreams.toml")
    if corpus.get("license") != entry["license"]:
        raise CorpusError(f"{relative} license differs from docs/upstreams.toml")
    return corpus


def _candidate_paths(target: Path, component: dict) -> list[str]:
    root = target / component["path"]
    requested_type = component["case_type"]
    if requested_type not in {"any", "directory", "file"}:
        raise CorpusError(
            f"{component['id']}: unknown case_type {requested_type!r}"
        )
    found: set[str] = set()
    for pattern in component["case_globs"]:
        if Path(pattern).is_absolute() or ".." in Path(pattern).parts:
            raise CorpusError(f"{component['id']}: unsafe case glob {pattern!r}")
        for path in root.glob(pattern):
            if requested_type == "directory" and not path.is_dir():
                continue
            if requested_type == "file" and not path.is_file():
                continue
            found.add(path.relative_to(target).as_posix())
    return sorted(found)


def audit_corpus(entry: dict) -> dict:
    """Verify a complete, pinned checkout and return its local inventory."""
    corpus = _load_corpus_manifest(entry)
    target = DEST / entry["name"]
    if not target.is_dir():
        raise CorpusError(f"{entry['name']} is not fetched")

    revision = _git(target, "rev-parse", "HEAD")
    tree = _git(target, "rev-parse", "HEAD^{tree}")
    origin = _git(target, "remote", "get-url", "origin")
    if revision != corpus["revision"]:
        raise CorpusError(
            f"{entry['name']}: revision {revision} != {corpus['revision']}"
        )
    if tree != corpus["tree"]:
        raise CorpusError(f"{entry['name']}: tree {tree} != {corpus['tree']}")
    if origin != corpus["origin"]:
        raise CorpusError(f"{entry['name']}: remote {origin!r} != {corpus['origin']!r}")
    tracked_output = _git(target, "ls-tree", "-r", "--name-only", "HEAD")
    tracked = tracked_output.splitlines() if tracked_output else []
    expected_tracked = corpus["expected_tracked_files"]
    if len(tracked) != expected_tracked:
        raise CorpusError(
            f"{entry['name']}: {len(tracked)} tracked files != {expected_tracked}"
        )
    missing = [path for path in tracked if not os.path.lexists(target / path)]
    if missing:
        sample = ", ".join(missing[:3])
        raise CorpusError(
            f"{entry['name']}: incomplete checkout, {len(missing)} path(s) missing: {sample}"
        )
    dirty = _git(target, "status", "--porcelain=v1", "--untracked-files=all")
    if dirty:
        first = dirty.splitlines()[0]
        raise CorpusError(f"{entry['name']}: checkout is modified ({first})")

    license_file = corpus["license_file"]
    if license_file not in tracked:
        raise CorpusError(f"{entry['name']}: missing declared license file {license_file}")
    license_digest = hashlib.sha256((target / license_file).read_bytes()).hexdigest()
    if license_digest != corpus["license_sha256"]:
        raise CorpusError(
            f"{entry['name']}: license digest {license_digest} != "
            f"{corpus['license_sha256']}"
        )

    components = []
    manifest_paths: set[str] = set()
    all_candidates: list[str] = []
    for component in corpus["component"]:
        component_path = component["path"].rstrip("/")
        prefix = f"{component_path}/"
        component_files = {
            path for path in tracked
            if path == component_path or path.startswith(prefix)
        }
        expected_files = component["expected_tracked_files"]
        if len(component_files) != expected_files:
            raise CorpusError(
                f"{component['id']}: {len(component_files)} tracked files != {expected_files}"
            )
        overlap = manifest_paths.intersection(component_files)
        if overlap:
            raise CorpusError(
                f"{component['id']}: component overlaps an earlier root at {min(overlap)}"
            )
        manifest_paths.update(component_files)

        candidates = _candidate_paths(target, component)
        expected_cases = component["expected_candidate_cases"]
        if len(candidates) != expected_cases:
            raise CorpusError(
                f"{component['id']}: {len(candidates)} candidate cases != {expected_cases}"
            )
        all_candidates.extend(f"{component['id']}:{path}" for path in candidates)
        components.append({
            "id": component["id"],
            "classification": component["classification"],
            "tracked_files": len(component_files),
            "candidate_cases": len(candidates),
            "candidates": candidates,
        })

    if len(manifest_paths) != corpus["expected_manifest_files"]:
        raise CorpusError(
            f"{entry['name']}: {len(manifest_paths)} manifest files != "
            f"{corpus['expected_manifest_files']}"
        )
    if len(all_candidates) != corpus["expected_candidate_cases"]:
        raise CorpusError(
            f"{entry['name']}: {len(all_candidates)} candidate cases != "
            f"{corpus['expected_candidate_cases']}"
        )

    return {
        "name": corpus["name"],
        "revision": revision,
        "tree": tree,
        "tracked_files": len(tracked),
        "manifest_files": len(manifest_paths),
        "candidate_cases": len(all_candidates),
        "components": components,
    }


def write_corpus_inventory(inventory: dict) -> Path:
    """Write filenames and counts locally without committing upstream content."""
    GENERATED.mkdir(parents=True, exist_ok=True)
    out = GENERATED / f"{inventory['name']}-corpus.md"
    lines = [
        f"# {inventory['name']} corpus inventory (generated, not committed)",
        "",
        f"Revision: `{inventory['revision']}`",
        f"Tree: `{inventory['tree']}`",
        f"Complete checkout: {inventory['tracked_files']} tracked files.",
        f"Manifest scope: {inventory['manifest_files']} tracked files.",
        f"Candidate cases: {inventory['candidate_cases']}.",
        "",
        "Candidates still require language, mode, oracle, and run-status classification.",
        "Presence in this inventory does not claim FortAD support.",
        "",
        "| component | classification | tracked files | candidates |",
        "|---|---|---:|---:|",
    ]
    for component in inventory["components"]:
        lines.append(
            f"| {component['id']} | {component['classification']} | "
            f"{component['tracked_files']} | {component['candidate_cases']} |"
        )
    lines += ["", "## Candidate paths", ""]
    for component in inventory["components"]:
        for candidate in component["candidates"]:
            lines.append(f"- `{component['id']}:{candidate}`")
    lines.append("")
    out.write_text("\n".join(lines))
    return out


def scan_corpora(entries: list[dict]) -> list[str]:
    failed = []
    for entry in entries:
        if "corpus_manifest" not in entry:
            continue
        out = GENERATED / f"{entry['name']}-corpus.md"
        if out.exists():
            out.unlink()
        try:
            inventory = audit_corpus(entry)
        except CorpusError as error:
            print(f"  FAIL   {entry['name']} corpus: {error}")
            failed.append(entry["name"])
            continue
        out = write_corpus_inventory(inventory)
        print(
            f"  corpus {entry['name']}: {inventory['candidate_cases']} candidates, "
            f"{inventory['tracked_files']} tracked files"
        )
        print(f"  wrote  {out.relative_to(ROOT)}")
    return failed


def scan_licenses(entries: list[dict]) -> None:
    """Re-read licence files from the checkouts and write a local inventory.

    The inventory lands under docs/generated/, which is gitignored: it quotes
    upstream licence text, and fortad does not redistribute upstream text.
    """
    GENERATED.mkdir(parents=True, exist_ok=True)
    out = GENERATED / "license-inventory.md"
    lines = [
        "# Local licence inventory (generated, not committed)",
        "",
        "Regenerate with `scripts/fetch_upstreams.py --licenses`.",
        "Declared values come from `docs/upstreams.toml`; licence-file names are",
        "read from the local checkout. A mismatch must be resolved before code in",
        "fortad is written against that project.",
        "",
        "| project | pinned ref | local revision | declared | licence files found |",
        "|---|---|---|---|---|",
    ]
    mismatches = 0
    for e in entries:
        target = DEST / e["name"]
        if e["ref"] in NON_GIT:
            lines.append(
                f"| {e['name']} | {e['ref']} | METADATA ONLY | {e['license']} | - |"
            )
            continue
        if not target.exists():
            lines.append(f"| {e['name']} | {e['ref']} | NOT FETCHED | {e['license']} | - |")
            continue
        found = sorted(
            p.name for p in target.iterdir()
            if p.is_file() and p.name.casefold() in LICENSE_NAMES_CASEFOLD
        )
        if not found:
            found_s = "**NONE FOUND**"
            mismatches += 1
        else:
            found_s = ", ".join(found)
        lines.append(
            f"| {e['name']} | {e['ref']} | {record_revision(e)[:12]} | "
            f"{e['license']} | {found_s} |"
        )
    lines += ["", f"Entries with no licence file: {mismatches}.", ""]
    out.write_text("\n".join(lines))
    print(f"\nwrote {out.relative_to(ROOT)}")
    if mismatches:
        print(f"WARNING: {mismatches} checkout(s) have no discoverable licence file. "
              "Treat those as all-rights-reserved: metadata only, no study of "
              "the source, no adaptation.")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="entry names to fetch (default: all)")
    ap.add_argument("--category", help="fetch one category only")
    ap.add_argument("--corpus", metavar="NAME",
                    help="fetch one corpus entry and verify its committed manifest")
    ap.add_argument("--audit-corpora", action="store_true",
                    help="verify existing corpus checkouts without network access")
    ap.add_argument("--depth", type=int, default=1, help="clone depth (default 1)")
    ap.add_argument("--list", action="store_true", help="list entries and exit")
    ap.add_argument("--licenses", action="store_true",
                    help="skip fetching, only rescan licences of existing checkouts")
    args = ap.parse_args()

    entries = load()
    if args.corpus and (args.names or args.category):
        ap.error("--corpus cannot be combined with names or --category")
    if args.category:
        entries = [e for e in entries if e["category"] == args.category]
    if args.corpus:
        entries = [e for e in entries if e["name"] == args.corpus]
        if not entries:
            print(f"unknown corpus: {args.corpus}", file=sys.stderr)
            return 2
        if "corpus_manifest" not in entries[0]:
            print(f"{args.corpus} has no corpus manifest", file=sys.stderr)
            return 2
    if args.names:
        wanted = set(args.names)
        entries = [e for e in entries if e["name"] in wanted]
        missing = wanted - {e["name"] for e in entries}
        if missing:
            print(f"unknown entries: {sorted(missing)}", file=sys.stderr)
            return 2

    if args.list:
        width = max(len(e["name"]) for e in entries)
        for e in entries:
            print(f"{e['name']:<{width}}  {e['category']:<11}  {e['license']}")
        return 0

    if args.licenses:
        scan_licenses(entries)
        return 0

    if args.audit_corpora:
        failed = scan_corpora(entries)
        return 1 if failed else 0

    DEST.mkdir(parents=True, exist_ok=True)
    print(f"fetching {len(entries)} upstream(s) into {DEST}\n")
    failed = [e["name"] for e in entries if not clone(e, args.depth)]
    scan_licenses(entries)
    fetched = [e for e in entries if e["name"] not in failed]
    failed += scan_corpora(fetched)
    if failed:
        print(f"\nfailed: {', '.join(failed)}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
