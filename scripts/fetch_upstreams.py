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
    scripts/fetch_upstreams.py --audit-pins    # report floating refs (no network)
    scripts/fetch_upstreams.py --write-corpus-triage tapenade
    scripts/fetch_upstreams.py --list
    scripts/fetch_upstreams.py --licenses      # re-scan checkouts, write inventory
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
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

LEDGER_COLUMNS = (
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
)
LEDGER_IDENTITY_COLUMNS = LEDGER_COLUMNS[:5]
LEDGER_WORKFLOW_COLUMNS = LEDGER_COLUMNS[5:]
FORTRAN_FIXED_SUFFIXES = {".f", ".for", ".ftn", ".f77"}
FORTRAN_FREE_SUFFIXES = {".f90", ".f95", ".f03", ".f08", ".f18", ".f2k"}
CPP_SUFFIXES = {".cc", ".cpp", ".cxx", ".c++"}
CUDA_SUFFIXES = {".cu"}
JULIA_SUFFIXES = {".jl"}
C_INCLUDE_SUFFIXES = {".h", ".hh", ".hpp", ".hxx", ".cuh"}
FORTRAN_INCLUDE_SUFFIXES = {".fh", ".inc"}
SOURCE_INCLUDE_SUFFIXES = C_INCLUDE_SUFFIXES | FORTRAN_INCLUDE_SUFFIXES
STATIC_TRIAGE_SCHEMA_VERSION = 1

FORTRAN_PROGRAM_RE = re.compile(r"^\s*program\s+([a-z][a-z0-9_]*)\b", re.IGNORECASE)
FORTRAN_SUBROUTINE_RE = re.compile(
    r"^\s*(?:(?:recursive|pure|elemental|impure|module)\s+)*"
    r"subroutine\s+([a-z][a-z0-9_]*)\b",
    re.IGNORECASE,
)
FORTRAN_FUNCTION_RE = re.compile(
    r"\bfunction\s+([a-z][a-z0-9_]*)\s*\(",
    re.IGNORECASE,
)
FORTRAN_USE_RE = re.compile(
    r"^\s*use(?:\s*,\s*[a-z][a-z0-9_]*)?\s*(?:::\s*)?"
    r"([a-z][a-z0-9_]*)\b",
    re.IGNORECASE,
)
FORTRAN_INCLUDE_RE = re.compile(r"^\s*include\s*['\"]([^'\"]+)['\"]", re.IGNORECASE)
CPP_INCLUDE_RE = re.compile(r"^\s*#\s*include\s*[<\"]([^>\"]+)[>\"]")
C_FUNCTION_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*\{")
JULIA_FUNCTION_RE = re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_!.]*)")
JULIA_SHORT_FUNCTION_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_!.]*)\s*\([^=]*\)\s*=")
JULIA_USE_RE = re.compile(r"^\s*(?:using|import)\s+([A-Za-z_][A-Za-z0-9_.]*)")


class CorpusError(RuntimeError):
    """The fetched checkout does not satisfy its committed corpus contract."""


def _metadata_only_reason(entry: dict) -> str:
    """Return the explicit policy reason for a non-git manifest entry.

    This deliberately reads only the committed manifest text.  It does not
    infer a legal status from a failed network request or from an absent local
    checkout.
    """
    text = " ".join(
        str(entry.get(field, "")) for field in ("license", "why", "adapt")
    ).casefold()
    if "restricted" in text:
        return "restricted"
    if "unavailable" in text:
        return "unavailable"
    if "unlicensed" in text or "no licence" in text or "none-found" in text:
        return "unlicensed"
    if "historical" in text:
        return "historical-source"
    return "metadata-only"


def _checkout_pin_metadata(entry: dict) -> dict[str, str]:
    """Read commit/tree/origin/cleanliness from an existing local checkout.

    The function is intentionally offline.  A missing checkout is reported as
    ``not-fetched`` rather than as an unavailable upstream; network
    reachability belongs to the fetch operation itself.
    """
    target = DEST / entry["name"]
    if not target.is_dir():
        return {
            "checkout": "not-fetched",
            "revision": "n/a",
            "tree": "n/a",
            "origin": "n/a",
        }
    if not (target / ".git").exists():
        return {
            "checkout": "invalid",
            "revision": "n/a",
            "tree": "n/a",
            "origin": "n/a",
        }
    try:
        revision = _git(target, "rev-parse", "HEAD")
        tree = _git(target, "rev-parse", "HEAD^{tree}")
        origin = _git(target, "remote", "get-url", "origin")
        dirty = bool(_git(target, "status", "--porcelain=v1", "--untracked-files=all"))
    except CorpusError:
        return {
            "checkout": "invalid",
            "revision": "n/a",
            "tree": "n/a",
            "origin": "n/a",
        }
    if origin != entry["url"]:
        checkout = "origin-mismatch"
    elif COMMIT_RE.fullmatch(entry["ref"]) and revision != entry["ref"]:
        checkout = "revision-mismatch"
    elif dirty:
        checkout = "dirty"
    else:
        checkout = "clean"
    return {
        "checkout": checkout,
        "revision": revision,
        "tree": tree,
        "origin": origin,
    }


def audit_upstream_pins(entries: list[dict]) -> list[dict[str, str]]:
    """Return an offline, deterministic audit of manifest ref provenance.

    ``ref = web`` entries are explicit metadata-only records.  A forty-digit
    ref is an immutable commit pin; every other git ref is deliberately marked
    as floating.  Existing checkouts contribute their verified HEAD and tree,
    but no hash is invented when a checkout is absent.
    """
    rows = []
    for entry in entries:
        ref = entry["ref"]
        if ref in NON_GIT:
            kind = "metadata-only"
            reason = _metadata_only_reason(entry)
        elif COMMIT_RE.fullmatch(ref):
            kind = "commit-pinned"
            reason = "git-source"
        else:
            kind = "floating-ref"
            reason = "git-source"
        row = {
            "name": entry["name"],
            "ref": ref,
            "kind": kind,
            "source": reason,
        }
        if kind == "metadata-only":
            row.update(
                checkout="not-applicable",
                revision="n/a",
                tree="n/a",
                origin="n/a",
            )
        else:
            row.update(_checkout_pin_metadata(entry))
        rows.append(row)
    return rows


def render_upstream_pin_audit(rows: list[dict[str, str]]) -> str:
    """Render the pin audit in stable, human-readable form."""
    lines = [
        "Upstream pin audit (offline; no network request)",
        "",
        "| project | declared ref | ref kind | source policy | checkout | revision | tree |",
        "|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['name']} | `{row['ref']}` | {row['kind']} | {row['source']} | "
            f"{row['checkout']} | `{row['revision']}` | `{row['tree']}` |"
        )
    counts = {
        "floating refs": sum(row["kind"] == "floating-ref" for row in rows),
        "commit-pinned refs": sum(row["kind"] == "commit-pinned" for row in rows),
        "metadata-only entries": sum(row["kind"] == "metadata-only" for row in rows),
        "not-fetched checkouts": sum(row["checkout"] == "not-fetched" for row in rows),
        "dirty or invalid checkouts": sum(
            row["checkout"] in {
                "dirty", "invalid", "origin-mismatch", "revision-mismatch"
            }
            for row in rows
        ),
    }
    lines += [
        "",
        "Summary: " + "; ".join(f"{value} {key}" for key, value in counts.items()) + ".",
    ]
    if counts["floating refs"] or counts["dirty or invalid checkouts"]:
        lines.append("Result: FAIL — commit-pin floating refs and repair checkout violations.")
    else:
        lines.append(
            "Result: PASS — every git ref is commit-pinned; fetched checkouts are clean."
        )
    return "\n".join(lines) + "\n"


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


def record_provenance(entry: dict) -> tuple[str, str]:
    """Return the exact local commit and tree, or n/a for non-Git entries."""
    target = DEST / entry["name"]
    rc = subprocess.run(
        ["git", "-C", str(target), "rev-parse", "HEAD", "HEAD^{tree}"],
        capture_output=True, text=True,
    )
    if rc.returncode != 0:
        return "n/a", "n/a"
    revision, tree = rc.stdout.splitlines()
    return revision, tree


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
    for field in ("status_ledger", "static_triage"):
        path = corpus.get(field)
        if path:
            relative_path = Path(path)
            if relative_path.is_absolute() or ".." in relative_path.parts:
                raise CorpusError(f"{relative} has unsafe {field} {path!r}")
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
    index_flags = _git(target, "ls-files", "-v")
    unusual_flag = next(
        (line for line in index_flags.splitlines() if not line.startswith("H ")),
        None,
    )
    if unusual_flag:
        raise CorpusError(
            f"{entry['name']}: checkout has non-default index flags ({unusual_flag})"
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
        "tracked_paths": tracked,
        "status_ledger": corpus.get("status_ledger"),
        "static_triage": corpus.get("static_triage"),
        "checkout": target,
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


def _candidate_tracked_paths(candidate: str, tracked_paths: list[str]) -> list[str]:
    prefix = f"{candidate.rstrip('/')}/"
    return [
        path for path in tracked_paths
        if path == candidate or path.startswith(prefix)
    ]


def _candidate_source_hints(candidate: str, tracked_paths: list[str]) -> tuple[str, str]:
    """Infer language and Fortran source form from tracked filename suffixes."""
    files = _candidate_tracked_paths(candidate, tracked_paths)
    suffixes = {Path(path).suffix for path in files}
    normalized_suffixes = {suffix.lower() for suffix in suffixes}
    languages = []
    if ".c" in suffixes:
        languages.append("c")
    if ".C" in suffixes or normalized_suffixes.intersection(CPP_SUFFIXES):
        languages.append("c++")
    if normalized_suffixes.intersection(CUDA_SUFFIXES):
        languages.append("cuda")
    has_fixed = bool(normalized_suffixes.intersection(FORTRAN_FIXED_SUFFIXES))
    has_free = bool(normalized_suffixes.intersection(FORTRAN_FREE_SUFFIXES))
    if has_fixed or has_free:
        languages.append("fortran")
    if normalized_suffixes.intersection(JULIA_SUFFIXES):
        languages.append("julia")

    language = "|".join(languages) if languages else "unknown"
    if "fortran" not in languages:
        source_form = "n/a"
    elif has_fixed and has_free:
        source_form = "mixed"
    elif has_fixed:
        source_form = "fixed"
    else:
        source_form = "free"
    return language, source_form


def _is_source_file(path: str) -> bool:
    suffix = Path(path).suffix
    normalized = suffix.lower()
    return (
        suffix == ".C"
        or normalized in FORTRAN_FIXED_SUFFIXES
        or normalized in FORTRAN_FREE_SUFFIXES
        or normalized in CPP_SUFFIXES
        or normalized in CUDA_SUFFIXES
        or normalized in JULIA_SUFFIXES
        or normalized in SOURCE_INCLUDE_SUFFIXES
        or suffix == ".c"
    )


def _static_source_hints(checkout: Path, source_files: list[str]) -> tuple[list, list, list]:
    entry_points: list[dict[str, str]] = []
    includes: list[dict[str, str]] = []
    uses: list[dict[str, str]] = []
    for source in source_files:
        suffix = Path(source).suffix
        normalized = suffix.lower()
        source_path = checkout / source
        if source_path.is_symlink():
            continue
        text = source_path.read_bytes().decode("utf-8", errors="replace")
        for line in text.splitlines():
            stripped = line.lstrip()
            if normalized in FORTRAN_FIXED_SUFFIXES and line[:1] in {"c", "C", "*", "!"}:
                continue
            if stripped.startswith("!"):
                continue
            match = CPP_INCLUDE_RE.match(line)
            if match:
                includes.append({"source": source, "target": match.group(1)})

            if normalized in (
                FORTRAN_FIXED_SUFFIXES | FORTRAN_FREE_SUFFIXES | FORTRAN_INCLUDE_SUFFIXES
            ):
                if not re.match(r"^\s*end\b", line, re.IGNORECASE):
                    match = FORTRAN_PROGRAM_RE.match(line)
                    if match:
                        entry_points.append({
                            "kind": "program",
                            "name": match.group(1).lower(),
                            "source": source,
                        })
                    match = FORTRAN_SUBROUTINE_RE.match(line)
                    if match:
                        entry_points.append({
                            "kind": "subroutine",
                            "name": match.group(1).lower(),
                            "source": source,
                        })
                    match = FORTRAN_FUNCTION_RE.search(line)
                    if match:
                        entry_points.append({
                            "kind": "function",
                            "name": match.group(1).lower(),
                            "source": source,
                        })
                match = FORTRAN_USE_RE.match(line)
                if match:
                    uses.append({"name": match.group(1).lower(), "source": source})
                match = FORTRAN_INCLUDE_RE.match(line)
                if match:
                    includes.append({"source": source, "target": match.group(1)})

            if suffix == ".c" or suffix == ".C" or normalized in (
                CPP_SUFFIXES | CUDA_SUFFIXES | C_INCLUDE_SUFFIXES
            ):
                if not stripped.startswith(("#", "//", "/*")):
                    match = C_FUNCTION_RE.search(line)
                    if match and match.group(1) not in {"if", "for", "while", "switch"}:
                        entry_points.append({
                            "kind": "function",
                            "name": match.group(1),
                            "source": source,
                        })

            if normalized in JULIA_SUFFIXES and not stripped.startswith("#"):
                match = JULIA_FUNCTION_RE.match(line) or JULIA_SHORT_FUNCTION_RE.match(line)
                if match:
                    entry_points.append({
                        "kind": "function",
                        "name": match.group(1),
                        "source": source,
                    })
                match = JULIA_USE_RE.match(line)
                if match:
                    uses.append({"name": match.group(1), "source": source})

    def unique_sorted(items: list[dict[str, str]]) -> list[dict[str, str]]:
        return [dict(values) for values in sorted({tuple(sorted(item.items())) for item in items})]

    return unique_sorted(entry_points), unique_sorted(includes), unique_sorted(uses)


def _static_classification(
    language: str,
    source_files: list[str],
    entry_points: list[dict[str, str]],
) -> str:
    if not source_files:
        return "harness-reference-data"
    languages = language.split("|")
    if language == "unknown":
        return "unknown-source"
    if "fortran" in languages and len(languages) > 1:
        return "mixed-language-source"
    if language != "fortran":
        return "non-fortran-source"
    kinds = {entry["kind"] for entry in entry_points}
    if "program" in kinds:
        return "fortran-runnable-candidate"
    if kinds.intersection({"subroutine", "function"}):
        return "fortran-procedure-candidate"
    return "fortran-source-candidate"


def static_triage_rows(inventory: dict) -> list[dict]:
    """Extract reproducible syntax hints without making transformation claims."""
    rows = []
    tracked_paths = inventory["tracked_paths"]
    checkout = inventory["checkout"]
    for component in inventory["components"]:
        for candidate in component["candidates"]:
            language, source_form = _candidate_source_hints(candidate, tracked_paths)
            candidate_paths = _candidate_tracked_paths(candidate, tracked_paths)
            source_files = sorted(path for path in candidate_paths if _is_source_file(path))
            entry_points, includes, uses = _static_source_hints(checkout, source_files)
            rows.append({
                "classification": _static_classification(
                    language, source_files, entry_points
                ),
                "component": component["id"],
                "entry_point_hints": entry_points,
                "include_hints": includes,
                "language": language,
                "path": candidate,
                "schema_version": STATIC_TRIAGE_SCHEMA_VERSION,
                "source_files": source_files,
                "source_form_hint": source_form,
                "use_hints": uses,
            })
    if len(rows) != inventory["candidate_cases"]:
        raise CorpusError(
            f"{inventory['name']}: {len(rows)} static triage rows != "
            f"{inventory['candidate_cases']} candidates"
        )
    return rows


def render_static_triage(inventory: dict) -> bytes:
    lines = [
        json.dumps(row, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        for row in static_triage_rows(inventory)
    ]
    return ("\n".join(lines) + "\n").encode("utf-8")


def _static_triage_path(inventory: dict) -> Path:
    relative = inventory.get("static_triage")
    if not relative:
        raise CorpusError(f"{inventory['name']}: corpus manifest has no static_triage")
    return ROOT / relative


def write_static_triage(inventory: dict) -> Path:
    out = _static_triage_path(inventory)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(render_static_triage(inventory))
    return out


def audit_static_triage(inventory: dict) -> int:
    if not inventory.get("static_triage"):
        return 0
    report = _static_triage_path(inventory)
    if not report.is_file():
        raise CorpusError(
            f"{inventory['name']}: missing static triage {report.relative_to(ROOT)}"
        )
    rendered = render_static_triage(inventory)
    if report.read_bytes() != rendered:
        raise CorpusError(
            f"{inventory['name']}: static triage differs from pinned checkout"
        )
    return inventory["candidate_cases"]


def initial_corpus_ledger_rows(inventory: dict) -> list[dict[str, str]]:
    """Return a deterministic, evidence-neutral row for every candidate."""
    rows = []
    tracked_paths = inventory["tracked_paths"]
    for component in inventory["components"]:
        for candidate in component["candidates"]:
            language, source_form = _candidate_source_hints(candidate, tracked_paths)
            rows.append({
                "component": component["id"],
                "path": candidate,
                "language": language,
                "source_form_hint": source_form,
                "initial_classification": component["classification"],
                "status": "untriaged",
                "entry_point": "untriaged",
                "tapenade_options": "untriaged",
                "modes": "untriaged",
                "oracle": "untriaged",
                "dependencies": "untriaged",
                "tapenade_result": "not-run",
                "fortad_result": "not-run",
            })
    if len(rows) != inventory["candidate_cases"]:
        raise CorpusError(
            f"{inventory['name']}: {len(rows)} ledger rows != "
            f"{inventory['candidate_cases']} candidates"
        )
    return rows


def render_initial_corpus_ledger(inventory: dict) -> str:
    """Render the initial CSV ledger with stable ordering and line endings."""
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(
        stream,
        fieldnames=LEDGER_COLUMNS,
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(initial_corpus_ledger_rows(inventory))
    return stream.getvalue()


def _corpus_ledger_path(inventory: dict) -> Path:
    relative = inventory.get("status_ledger")
    if not relative:
        raise CorpusError(f"{inventory['name']}: corpus manifest has no status_ledger")
    return ROOT / relative


def write_initial_corpus_ledger(inventory: dict) -> Path:
    """Create the committed untriaged scaffold from the audited checkout."""
    out = _corpus_ledger_path(inventory)
    out.parent.mkdir(parents=True, exist_ok=True)
    rendered = render_initial_corpus_ledger(inventory)
    encoded = rendered.encode("utf-8")
    if out.exists() and out.read_bytes() != encoded:
        raise CorpusError(
            f"{inventory['name']}: refusing to overwrite curated status ledger "
            f"{out.relative_to(ROOT)}"
        )
    out.write_bytes(encoded)
    return out


def audit_corpus_ledger(inventory: dict) -> int:
    """Verify exact candidate coverage while preserving later evidence fields."""
    if not inventory.get("status_ledger"):
        return 0
    ledger = _corpus_ledger_path(inventory)
    if not ledger.is_file():
        raise CorpusError(f"{inventory['name']}: missing status ledger {ledger.relative_to(ROOT)}")
    with ledger.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        if tuple(reader.fieldnames or ()) != LEDGER_COLUMNS:
            raise CorpusError(
                f"{inventory['name']}: status ledger columns differ from schema"
            )
        rows = list(reader)

    expected = initial_corpus_ledger_rows(inventory)
    if len(rows) != len(expected):
        raise CorpusError(
            f"{inventory['name']}: {len(rows)} status rows != {len(expected)} candidates"
        )
    for line_number, (row, seed) in enumerate(zip(rows, expected), start=2):
        if None in row or any(value is None for value in row.values()):
            raise CorpusError(
                f"{inventory['name']}: malformed status ledger row {line_number}"
            )
        for column in LEDGER_IDENTITY_COLUMNS:
            if row[column] != seed[column]:
                raise CorpusError(
                    f"{inventory['name']}: status row {line_number} has unexpected {column}"
                )
        missing = [column for column in LEDGER_WORKFLOW_COLUMNS if not row[column].strip()]
        if missing:
            raise CorpusError(
                f"{inventory['name']}: status row {line_number} has empty {missing[0]}"
            )
        if row["status"] == "untriaged":
            changed = [
                column for column in LEDGER_WORKFLOW_COLUMNS[1:]
                if row[column] != seed[column]
            ]
            if changed:
                raise CorpusError(
                    f"{inventory['name']}: untriaged status row {line_number} "
                    f"changes {changed[0]}"
                )
        else:
            placeholders = [
                column for column in LEDGER_WORKFLOW_COLUMNS[1:]
                if row[column] == "untriaged"
            ]
            if placeholders:
                raise CorpusError(
                    f"{inventory['name']}: classified status row {line_number} "
                    f"leaves {placeholders[0]} untriaged"
                )
    return len(rows)


def discard_corpus_inventory(entry: dict) -> None:
    if "corpus_manifest" not in entry:
        return
    out = GENERATED / f"{entry['name']}-corpus.md"
    if out.exists():
        out.unlink()


def scan_corpora(entries: list[dict]) -> list[str]:
    failed = []
    for entry in entries:
        if "corpus_manifest" not in entry:
            continue
        discard_corpus_inventory(entry)
        try:
            inventory = audit_corpus(entry)
            ledger_rows = audit_corpus_ledger(inventory)
            triage_rows = audit_static_triage(inventory)
        except CorpusError as error:
            print(f"  FAIL   {entry['name']} corpus: {error}")
            failed.append(entry["name"])
            continue
        out = write_corpus_inventory(inventory)
        print(
            f"  corpus {entry['name']}: {inventory['candidate_cases']} candidates, "
            f"{inventory['tracked_files']} tracked files"
        )
        if ledger_rows:
            print(f"  ledger {entry['name']}: {ledger_rows} status rows")
        if triage_rows:
            print(f"  triage {entry['name']}: {triage_rows} static rows")
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
        "| project | pinned ref | local revision | local tree | declared | licence files found |",
        "|---|---|---|---|---|---|",
    ]
    mismatches = 0
    for e in entries:
        target = DEST / e["name"]
        if e["ref"] in NON_GIT:
            lines.append(
                f"| {e['name']} | {e['ref']} | METADATA ONLY | - | "
                f"{e['license']} | - |"
            )
            continue
        if not target.exists():
            lines.append(
                f"| {e['name']} | {e['ref']} | NOT FETCHED | - | "
                f"{e['license']} | - |"
            )
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
        revision, tree = record_provenance(e)
        lines.append(
            f"| {e['name']} | {e['ref']} | {revision} | {tree} | "
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
    ap.add_argument("--audit-pins", action="store_true",
                    help="audit commit pins and local commit/tree metadata without network access")
    ap.add_argument("--seed-corpus-ledger", metavar="NAME",
                    help="write an untriaged status ledger from an audited checkout")
    ap.add_argument("--write-corpus-triage", metavar="NAME",
                    help="write static source hints from an audited checkout")
    ap.add_argument("--depth", type=int, default=1, help="clone depth (default 1)")
    ap.add_argument("--list", action="store_true", help="list entries and exit")
    ap.add_argument("--licenses", action="store_true",
                    help="skip fetching, only rescan licences of existing checkouts")
    args = ap.parse_args()

    entries = load()
    if args.audit_pins and (
        args.corpus or args.seed_corpus_ledger or args.write_corpus_triage
        or args.licenses or args.audit_corpora or args.list
    ):
        ap.error("--audit-pins cannot be combined with corpus, licence, audit, seed, triage, or list operations")
    if args.seed_corpus_ledger and (
        args.names or args.category or args.corpus or args.audit_corpora
        or args.list or args.licenses or args.write_corpus_triage or args.audit_pins
    ):
        ap.error("--seed-corpus-ledger cannot be combined with other operations")
    if args.write_corpus_triage and (
        args.names or args.category or args.corpus or args.audit_corpora
        or args.list or args.licenses or args.seed_corpus_ledger or args.audit_pins
    ):
        ap.error("--write-corpus-triage cannot be combined with other operations")
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

    if args.seed_corpus_ledger:
        entries = [e for e in entries if e["name"] == args.seed_corpus_ledger]
        if not entries:
            print(f"unknown corpus: {args.seed_corpus_ledger}", file=sys.stderr)
            return 2
        try:
            inventory = audit_corpus(entries[0])
            out = write_initial_corpus_ledger(inventory)
            audit_corpus_ledger(inventory)
        except CorpusError as error:
            print(f"  FAIL   {args.seed_corpus_ledger} ledger: {error}")
            return 1
        print(
            f"  wrote  {out.relative_to(ROOT)} "
            f"({inventory['candidate_cases']} untriaged rows)"
        )
        return 0

    if args.write_corpus_triage:
        entries = [e for e in entries if e["name"] == args.write_corpus_triage]
        if not entries:
            print(f"unknown corpus: {args.write_corpus_triage}", file=sys.stderr)
            return 2
        try:
            inventory = audit_corpus(entries[0])
            out = write_static_triage(inventory)
            audit_static_triage(inventory)
        except CorpusError as error:
            print(f"  FAIL   {args.write_corpus_triage} triage: {error}")
            return 1
        print(
            f"  wrote  {out.relative_to(ROOT)} "
            f"({inventory['candidate_cases']} static rows)"
        )
        return 0

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

    if args.audit_pins:
        rows = audit_upstream_pins(entries)
        print(render_upstream_pin_audit(rows), end="")
        return 1 if any(
            row["kind"] == "floating-ref"
            or row["checkout"] in {
                "dirty", "invalid", "origin-mismatch", "revision-mismatch"
            }
            for row in rows
        ) else 0

    DEST.mkdir(parents=True, exist_ok=True)
    for entry in entries:
        discard_corpus_inventory(entry)
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
