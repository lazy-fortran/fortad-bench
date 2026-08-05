#!/usr/bin/env python3
"""Resolve fortad's bibliography and fetch only openly licensed full text.

Publisher PDFs are never committed.  The resolver records bibliographic
matches and open-access locations in the gitignored ``literature/resolved.json``;
unmatched or closed papers remain available for institutional retrieval.

Usage:
    scripts/fetch_literature.py --resolve
    scripts/fetch_literature.py --fetch
    scripts/fetch_literature.py --report
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIB = ROOT / "docs" / "bibliography.bib"
DEST = ROOT / "literature"
RESOLVED = DEST / "resolved.json"
EMAIL = os.environ.get("FORTAD_CONTACT_EMAIL", "albert@tugraz.at")
UA = f"fortad-literature/1 (https://github.com/lazy-fortran/fortad; mailto:{EMAIL})"

ENTRY_RE = re.compile(r"@(\w+)\{([^,]+),(.*?)\n\}", re.S)
FIELD_RE = re.compile(r"(\w+)\s*=\s*\{(.*?)\}\s*,?\s*\n", re.S)
STOP_WORDS = frozenset(
    "a an and are been for in is of on the to using via we what where with".split()
)


def strip_tex(value: str) -> str:
    value = re.sub(r"[{}\\]", "", value)
    return re.sub(r"\s+", " ", value).strip()


def parse_bib() -> list[dict[str, str]]:
    entries = []
    for kind, key, body in ENTRY_RE.findall(BIB.read_text()):
        fields = {k.lower(): strip_tex(v) for k, v in FIELD_RE.findall(body + "\n")}
        fields["_key"] = key.strip()
        fields["_type"] = kind
        entries.append(fields)
    return entries


def get_json(url: str, timeout: int = 20) -> dict:
    request = urllib.request.Request(
        url, headers={"User-Agent": UA, "Accept": "application/json"}
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except (OSError, ValueError, json.JSONDecodeError):
        return {}


def title_matches(got: str, want: str) -> bool:
    words = {w for w in re.findall(r"[a-z0-9]+", want.lower())
             if w not in STOP_WORDS and len(w) > 2}
    found = {w for w in re.findall(r"[a-z0-9]+", got.lower())
             if w not in STOP_WORDS and len(w) > 2}
    if not words or not found:
        return False
    shared = words & found
    return len(shared) >= 3 and len(shared) / min(len(words), len(found)) >= 0.75


def crossref(entry: dict[str, str]) -> dict | None:
    query = urllib.parse.urlencode({
        "query.bibliographic": f"{entry.get('title', '')} {entry.get('author', '')}",
        "rows": 1,
        "mailto": EMAIL,
    })
    items = get_json(f"https://api.crossref.org/works?{query}").get("message", {}).get("items", [])
    if not items:
        return None
    item = items[0]
    titles = item.get("title") or []
    matched = strip_tex(titles[0]) if titles else ""
    if not title_matches(matched, entry.get("title", "")):
        return None
    issued = item.get("issued", {}).get("date-parts", [[None]])
    return {
        "doi": item.get("DOI"),
        "matched_title": matched,
        "container": (item.get("container-title") or [""])[0],
        "year": issued[0][0] if issued and issued[0] else None,
    }


def unpaywall(doi: str) -> dict | None:
    data = get_json(f"https://api.unpaywall.org/v2/{urllib.parse.quote(doi)}?email={urllib.parse.quote(EMAIL)}")
    location = data.get("best_oa_location")
    if not location:
        return None
    return {
        "url": location.get("url_for_pdf") or location.get("url"),
        "license": location.get("license"),
        "version": location.get("version"),
        "host": location.get("host_type"),
    }


def arxiv(entry: dict[str, str]) -> dict | None:
    if entry.get("eprint") and entry.get("archiveprefix", "").lower() == "arxiv":
        arxiv_id = entry["eprint"]
        return {"arxiv_id": arxiv_id, "pdf": f"https://arxiv.org/pdf/{arxiv_id}"}
    query = urllib.parse.urlencode({
        "search_query": f'ti:"{entry.get("title", "")[:120]}"',
        "max_results": 1,
    })
    request = urllib.request.Request(
        f"https://export.arxiv.org/api/query?{query}", headers={"User-Agent": UA}
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            xml = response.read().decode("utf-8", "replace")
    except OSError:
        return None
    first = xml.find("<entry>")
    if first < 0:
        return None
    body = xml[first:]
    match = re.search(r"<id>https?://arxiv\.org/abs/([^<]+)</id>", body)
    title = re.search(r"<title>(.*?)</title>", body, re.S)
    if not match or not title:
        return None
    matched = re.sub(r"\s+", " ", title.group(1)).strip()
    if not title_matches(matched, entry.get("title", "")):
        return None
    arxiv_id = match.group(1)
    return {"arxiv_id": arxiv_id, "pdf": f"https://arxiv.org/pdf/{arxiv_id}"}


def download(url: str, destination: Path) -> bool:
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
    except OSError as exc:
        print(f"    download failed: {exc}")
        return False
    if not data.startswith(b"%PDF"):
        print("    not a PDF, skipped")
        return False
    destination.write_bytes(data)
    return True


def report(entries: list[dict[str, str]], state: dict) -> int:
    local = {p.stem for p in DEST.glob("*.pdf")}
    print(f"{len(entries)} bibliography entries, {len(local)} local PDFs\n")
    for entry in entries:
        key = entry["_key"]
        record = state.get(key, {})
        mark = "PDF" if key in local else "   "
        print(f"  [{mark}] {key:<28} {record.get('doi', '')}")
    print("\nEntries without a local PDF are not missing data. Retrieve them through "
          "institutional access or Zotero if full text is needed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--resolve", action="store_true")
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args()
    if not (args.resolve or args.fetch or args.report):
        parser.print_help()
        return 0

    DEST.mkdir(parents=True, exist_ok=True)
    entries = parse_bib()
    state = json.loads(RESOLVED.read_text()) if RESOLVED.exists() else {}
    if args.report:
        return report(entries, state)

    for entry in entries:
        key = entry["_key"]
        record = state.setdefault(key, {"title": entry.get("title", "")})
        print(key)
        if "doi" not in record:
            match = crossref(entry)
            if match:
                record.update(match)
                print(f"    crossref doi={match['doi']}")
            else:
                print("    crossref: no confident match (DOI left unset on purpose)")
            time.sleep(0.4)
        if "arxiv_id" not in record:
            match = arxiv(entry) if not record.get("doi") else None
            if match:
                record.update(match)
                print(f"    arxiv {match['arxiv_id']}")
            time.sleep(0.4)
        if record.get("doi") and "oa" not in record:
            record["oa"] = unpaywall(record["doi"])
            if record["oa"]:
                print(f"    open access: {record['oa'].get('license')} via {record['oa'].get('host')}")
            time.sleep(0.3)
        if not args.fetch:
            continue
        target = DEST / f"{key}.pdf"
        if target.exists():
            continue
        url = record.get("pdf")
        if not url and record.get("oa") and record["oa"].get("license"):
            url = record["oa"].get("url")
        if url:
            print(f"    fetching {url}")
            if download(url, target):
                print(f"    -> literature/{key}.pdf")
        else:
            print("    no openly licensed copy; retrieve via institutional access")

    RESOLVED.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
    print(f"\nwrote {RESOLVED.relative_to(ROOT)} (gitignored)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
