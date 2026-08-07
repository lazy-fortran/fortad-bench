#!/usr/bin/env python3
"""Run bounded Tapenade/FortAD source probes from manifests or the queue.

This command is an evidence-producing workflow, not a correctness oracle.  A
manifest can name one procedure, while queue mode automatically expands every
canonical source procedure found by static triage.  Ambiguous cases are still
recorded without running a transform when no source procedure is discoverable,
so the workflow never silently invents active or dependent arguments.

Examples::

    scripts/probe_tapenade_fortad.py --case nonRegressions/set01/ht02
    scripts/probe_tapenade_fortad.py --manifest cases/tapenade-set01/lh093/manifest.toml
    scripts/probe_tapenade_fortad.py --queue --shard-count 8 --shard-index 0 \
        --jobs 4 --result-dir /var/tmp/fortad-tapenade-probes

The queue mode writes one JSON object per candidate to ``results.jsonl`` and
keeps generated products under the selected result directory.  The pinned
upstream checkout is never modified.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import time
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "upstream" / "tapenade"
QUEUE = ROOT / "docs" / "corpora" / "tapenade-fortran-queue.jsonl"
STATIC = ROOT / "docs" / "corpora" / "tapenade-static.jsonl"
TAPENADE_REVISION = "e59864cab441d4175df75383b3ff58c3dcd26df9"
FIXED_SUFFIXES = {".f", ".for", ".ftn"}
FORTRAN_SUFFIXES = FIXED_SUFFIXES | {".f90", ".f95", ".f03", ".f08"}
GENERATED_NAME = re.compile(
    r"(?:_b|_d|_p|_dv|_fwd|_bwd|_adj|_tangent)$", re.IGNORECASE
)
ENTRY_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*(?:\((.*)\))?\s*$")


@dataclass(frozen=True)
class ProbeSpec:
    case_path: str
    source: str
    entry_point: str | None
    independent: tuple[str, ...]
    dependent: str | None
    modes: tuple[str, ...]
    manifest: str | None = None


def _load_jsonl(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def _git_revision(path: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return result.stdout.strip()


def _git_root_for_executable(path: Path) -> Path:
    for candidate in (path.parent, *path.parents):
        if (candidate / ".git").exists():
            return candidate
    return path.parent


def _fortran_sources(case: Path) -> list[Path]:
    return sorted(
        path for path in case.iterdir() if path.is_file() and path.suffix.lower() in FORTRAN_SUFFIXES
    )


def _source_priority(path: Path) -> tuple[int, str]:
    name = path.name.lower()
    if name in {"program.f", "program.f90"}:
        return (0, name)
    if name.startswith("program."):
        return (1, name)
    return (2, name)


def _select_source(case: Path, requested: str | None = None) -> Path:
    if requested:
        candidate = UPSTREAM / requested
        if not candidate.is_file():
            raise ValueError(f"manifest source is not present: {requested}")
        return candidate
    sources = _fortran_sources(case)
    if not sources:
        raise ValueError(f"no Fortran source in {case.relative_to(UPSTREAM)}")
    return min(sources, key=_source_priority)


def _entry_name(entry: str | None) -> str | None:
    if not entry:
        return None
    match = ENTRY_RE.match(entry)
    if not match:
        return None
    return match.group(1).lower()


def _entry_args(entry: str | None) -> tuple[str, ...]:
    if not entry:
        return ()
    match = ENTRY_RE.match(entry)
    if not match or match.group(2) is None:
        return ()
    return tuple(token.lower() for token in re.split(r"[\s,]+", match.group(2).strip()) if token)


def _canonical_hints(case_path: str, source: str) -> list[str]:
    if not STATIC.is_file():
        return []
    source = source.replace("\\", "/")
    names: list[str] = []
    for row in _load_jsonl(STATIC):
        if row.get("path") != case_path:
            continue
        for hint in row.get("entry_point_hints", []):
            name = str(hint.get("name", "")).strip().lower()
            hint_source = str(hint.get("source", "")).replace("\\", "/")
            if not name or hint_source != source:
                continue
            if GENERATED_NAME.search(name):
                continue
            if hint.get("kind") == "program":
                continue
            if name not in names:
                names.append(name)
    return names


def _manifest_case(data: dict[str, Any]) -> dict[str, Any]:
    cases = data.get("case")
    if isinstance(cases, list):
        if len(cases) != 1:
            raise ValueError("a probe manifest must contain exactly one [[case]] entry")
        return {**data, **cases[0]}
    return data


def spec_from_manifest(path: Path) -> ProbeSpec:
    with path.open("rb") as stream:
        data = _manifest_case(tomllib.load(stream))
    upstream_sources = data.get("upstream_sources") or []
    requested_source = data.get("upstream_source")
    if not requested_source:
        requested_source = next(
            (item for item in upstream_sources if Path(item).suffix.lower() in FORTRAN_SUFFIXES),
            None,
        )
    if not requested_source:
        raise ValueError(f"manifest has no Fortran upstream source: {path}")
    requested_source = str(requested_source)
    source = _select_source(UPSTREAM / Path(requested_source).parent, requested_source)
    case_path = str(source.relative_to(UPSTREAM).parent).replace("\\", "/")
    raw_modes = data.get("modes", ["parser", "forward", "reverse"])
    if isinstance(raw_modes, str):
        raw_modes = [raw_modes]
    modes = tuple(
        mode
        for mode in (str(item).split(":", 1)[0].lower() for item in raw_modes)
        if mode in {"parser", "forward", "reverse"}
    ) or ("parser", "forward", "reverse")
    independent = data.get("independent", [])
    if isinstance(independent, str):
        independent = [independent]
    entry = str(data.get("upstream_entry_point", "")) or None
    dependent = data.get("dependent")
    if isinstance(dependent, list):
        dependent = dependent[0] if len(dependent) == 1 else None
    return ProbeSpec(
        case_path=case_path,
        source=str(source.relative_to(UPSTREAM)).replace("\\", "/"),
        entry_point=_entry_name(entry),
        independent=tuple(str(item) for item in independent),
        dependent=str(dependent) if dependent else None,
        modes=modes,
        manifest=str(path),
    )


def spec_from_case(case_path: str) -> ProbeSpec:
    specs = specs_from_case(case_path)
    return specs[0]


def specs_from_case(case_path: str, all_entries: bool = False) -> list[ProbeSpec]:
    case_path = case_path.replace("\\", "/").strip("/")
    case = UPSTREAM / case_path
    if not case.is_dir():
        raise ValueError(f"upstream case directory is not present: {case_path}")
    source = _select_source(case)
    source_name = str(source.relative_to(UPSTREAM)).replace("\\", "/")
    hints = _canonical_hints(case_path, source_name)
    if all_entries:
        # Preserve one explicit refusal record when static discovery finds no
        # canonical procedure.  Dropping the row makes a shard look complete
        # while silently losing a corpus candidate.
        entries = hints or [None]
    else:
        entries = hints[:1] if len(hints) == 1 else [None]
    return [
        ProbeSpec(
            case_path=case_path,
            source=source_name,
            entry_point=entry,
            independent=(),
            dependent=None,
            modes=("parser", "forward", "reverse"),
        )
        for entry in entries
    ]


def _executable(env_name: str, default: Path) -> Path | None:
    value = os.environ.get(env_name)
    if value:
        return Path(value)
    return default if default.is_file() else None


def _tail(text: str, limit: int = 4096) -> str:
    text = text.strip()
    return text if len(text) <= limit else "..." + text[-limit:]


def _run(
    command: list[str],
    cwd: Path,
    output_dir: Path,
    timeout: int,
    env: dict[str, str],
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)

    def diagnostics(stdout: str, stderr: str) -> dict[str, str]:
        (output_dir / "stdout.txt").write_text(stdout, encoding="utf-8")
        (output_dir / "stderr.txt").write_text(stderr, encoding="utf-8")
        return {"stdout": "stdout.txt", "stderr": "stderr.txt"}

    started = time.monotonic()
    try:
        process = subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
        )
    except FileNotFoundError as error:
        diagnostic_files = diagnostics("", str(error))
        return {
            "status": "missing-executable",
            "returncode": 127,
            "seconds": round(time.monotonic() - started, 6),
            "command": command,
            "error": str(error),
            "diagnostics": diagnostic_files,
            "generated": [],
        }
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout or ""
        stderr = error.stderr or ""
        diagnostic_files = diagnostics(stdout, stderr)
        return {
            "status": "timeout",
            "returncode": 124,
            "seconds": round(time.monotonic() - started, 6),
            "command": command,
            "stdout": _tail(stdout),
            "stderr": _tail(stderr),
            "diagnostics": diagnostic_files,
            "generated": [],
        }
    diagnostic_files = diagnostics(process.stdout, process.stderr)
    generated = sorted(
        str(path.relative_to(output_dir)).replace("\\", "/")
        for path in output_dir.rglob("*")
        if path.is_file() and path.name not in {"stdout.txt", "stderr.txt"}
    )
    return {
        "status": "pass" if process.returncode == 0 else "refused",
        "returncode": process.returncode,
        "seconds": round(time.monotonic() - started, 6),
        "command": command,
        "stdout": _tail(process.stdout),
        "stderr": _tail(process.stderr),
        "diagnostics": diagnostic_files,
        "generated": generated,
    }


def _probe_tool(
    tool: Path | None,
    name: str,
    spec: ProbeSpec,
    output_dir: Path,
    timeout: int,
    env: dict[str, str],
) -> dict[str, Any]:
    if tool is None:
        return {"status": "missing-executable", "returncode": 127, "generated": []}
    source = Path(spec.source)
    command = [str(tool), "-O", str(output_dir), "-o", "probe"]
    if spec.entry_point:
        command += ["-root", spec.entry_point]
    command += [source.name]
    if name == "parser":
        command.insert(1, "-p")
    elif name == "forward":
        command.insert(1, "-d")
    else:
        command.insert(1, "-b")
    return _run(command, UPSTREAM / spec.case_path, output_dir, timeout, env)


def _probe_fortad(
    tool: Path | None,
    name: str,
    spec: ProbeSpec,
    output_dir: Path,
    timeout: int,
    env: dict[str, str],
) -> dict[str, Any]:
    if tool is None:
        return {"status": "missing-executable", "returncode": 127, "generated": []}
    source = Path(spec.source)
    command = [str(tool), f"-{ {'parser': 'p', 'forward': 'd', 'reverse': 'b'}[name]}"]
    if spec.entry_point:
        command += ["-root", spec.entry_point]
    if name == "reverse" and spec.dependent:
        command += ["--dep", spec.dependent]
    command += ["-O", str(output_dir), "-o", "probe", source.name]
    return _run(command, UPSTREAM / spec.case_path, output_dir, timeout, env)


def probe_spec(
    spec: ProbeSpec,
    result_dir: Path,
    tapenade: Path | None,
    fortad: Path | None,
    timeout: int = 120,
) -> dict[str, Any]:
    result_dir.mkdir(parents=True, exist_ok=True)
    case = UPSTREAM / spec.case_path
    env = {**os.environ, "PATH": f"{UPSTREAM / 'bin'}:{os.environ.get('PATH', '')}"}
    record: dict[str, Any] = {
        "schema_version": 1,
        "case_path": spec.case_path,
        "source": spec.source,
        "entry_point": spec.entry_point,
        "independent": list(spec.independent),
        "dependent": spec.dependent,
        "modes": list(spec.modes),
        "manifest": spec.manifest,
        "upstream_revision": _git_revision(UPSTREAM),
        "expected_upstream_revision": TAPENADE_REVISION,
        "fortad_revision": _git_revision(_git_root_for_executable(fortad)) if fortad else None,
        "selection": "explicit" if spec.manifest or spec.entry_point else "static-unambiguous",
        "result_dir": str(result_dir),
        "probes": {},
    }
    if not case.is_dir():
        record["status"] = "missing-case"
        return record
    if not spec.entry_point:
        record["status"] = "ambiguous-entry-point"
        record["reason"] = (
            "static triage found zero or multiple source procedures; provide --manifest "
            "or an explicit --entry-point"
        )
        return record
    for mode in spec.modes:
        mode_dir = result_dir / mode
        tap = _probe_tool(tapenade, mode, spec, mode_dir / "tapenade", timeout, env)
        fad = _probe_fortad(fortad, mode, spec, mode_dir / "fortad", timeout, env)
        record["probes"][mode] = {"tapenade": tap, "fortad": fad}
    statuses = [
        probe[tool]["status"]
        for probe in record["probes"].values()
        for tool in ("tapenade", "fortad")
    ]
    record["status"] = "pass" if statuses and all(status == "pass" for status in statuses) else "probed"
    return record


def _path_slug(path: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "__", path).strip("_")


def _spec_slug(spec: ProbeSpec) -> str:
    suffix = f"__{_path_slug(spec.entry_point)}" if spec.entry_point else ""
    return _path_slug(spec.case_path) + suffix


def _queue_specs(args: argparse.Namespace) -> list[ProbeSpec]:
    rows = _load_jsonl(Path(args.queue_file))
    rows = [row for row in rows if args.include_classified or row.get("path")]
    rows = _select_queue_rows(rows, args.shard_index, args.shard_count)
    if args.limit is not None:
        rows = rows[: args.limit]
    specs: list[ProbeSpec] = []
    for row in rows:
        specs.extend(specs_from_case(row["path"], all_entries=True))
    return specs


def _select_queue_rows(rows: list[dict[str, Any]], index: int, count: int) -> list[dict[str, Any]]:
    """Select a deterministic, disjoint shard of queue rows.

    ``queue_rank`` is a priority bucket, not a row identifier: using it for
    sharding sends every row in a bucket to the same worker and leaves most
    shard indices empty.  The generated queue is already sorted, so its row
    ordinal is the stable partition key.  Keep the validation here as well as
    in ``main`` so callers and tests cannot accidentally create overlapping
    shards.
    """
    if count < 1 or not 0 <= index < count:
        raise ValueError("shard index must satisfy 0 <= index < shard count")
    return [row for ordinal, row in enumerate(rows) if ordinal % count == index]


def _write_record(path: Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _single_spec(args: argparse.Namespace) -> ProbeSpec:
    if args.manifest:
        spec = spec_from_manifest(Path(args.manifest))
    elif args.case:
        spec = spec_from_case(args.case)
    else:
        raise ValueError("choose --manifest, --case, or --queue")
    if args.entry_point:
        spec = ProbeSpec(
            **{**spec.__dict__, "entry_point": _entry_name(args.entry_point)}
        )
    return spec


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--manifest", help="single-case TOML manifest")
    source.add_argument("--case", help="relative case directory under upstream/tapenade")
    source.add_argument("--queue", action="store_true", help="probe the queued corpus candidates")
    parser.add_argument("--entry-point", help="explicit procedure name or NAME(args)")
    parser.add_argument(
        "--all-entry-points",
        action="store_true",
        help="probe every canonical source procedure for a single --case",
    )
    parser.add_argument("--queue-file", dest="queue_file", default=str(QUEUE), help=argparse.SUPPRESS)
    parser.add_argument("--result", help="single-case JSON output (default: stdout)")
    parser.add_argument("--result-dir", default="/var/tmp/fortad-tapenade-probes")
    parser.add_argument("--fortad", help="FortAD executable; defaults to FORTAD_CLI or the local build")
    parser.add_argument("--tapenade", help="Tapenade executable; defaults to TAPENADE_CLI or upstream/bin/tapenade")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--shard-count", type=int, default=1)
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--verbose", action="store_true", help="print the complete single-case JSON record")
    parser.add_argument("--include-classified", action="store_true", help=argparse.SUPPRESS)
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.shard_count < 1 or not 0 <= args.shard_index < args.shard_count:
        raise SystemExit("invalid shard selection")
    if args.jobs < 1:
        raise SystemExit("--jobs must be positive")
    if not UPSTREAM.is_dir():
        raise SystemExit("missing upstream/tapenade; run scripts/fetch_upstreams.py --corpus tapenade")
    tapenade = (
        Path(args.tapenade).resolve()
        if args.tapenade
        else _executable("TAPENADE_CLI", UPSTREAM / "bin" / "tapenade")
    )
    fortad_default = ROOT.parent / "fortad" / "build" / "fo" / "bin" / "fortad"
    fortad = (
        Path(args.fortad).resolve()
        if args.fortad
        else _executable("FORTAD_CLI", fortad_default)
    )
    if args.queue:
        specs = _queue_specs(args)
        result_dir = Path(args.result_dir).resolve()
        records: list[dict[str, Any]] = []

        def run(spec: ProbeSpec) -> dict[str, Any]:
            return probe_spec(
                spec,
                result_dir / _spec_slug(spec),
                tapenade,
                fortad,
                args.timeout,
            )

        if args.jobs > 1:
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
                records = list(pool.map(run, specs))
        else:
            records = [run(spec) for spec in specs]
        records.sort(key=lambda item: (item["case_path"], item.get("entry_point") or ""))
        result_path = result_dir / "results.jsonl"
        result_path.parent.mkdir(parents=True, exist_ok=True)
        result_path.write_text(
            "".join(json.dumps(record, sort_keys=True) + "\n" for record in records),
            encoding="utf-8",
        )
        print(json.dumps({
            "result": str(result_path),
            "cases": len({record["case_path"] for record in records}),
            "entry_point_probes": len(records),
        }))
        return 0

    spec = _single_spec(args)
    if args.case and args.all_entry_points:
        specs = specs_from_case(args.case, all_entries=True)
        result_dir = Path(args.result_dir).resolve()
        records = [
            probe_spec(spec, result_dir / _spec_slug(spec), tapenade, fortad, args.timeout)
            for spec in specs
        ]
        records.sort(key=lambda item: item.get("entry_point") or "")
        result_path = Path(args.result) if args.result else result_dir / "results.jsonl"
        result_path.parent.mkdir(parents=True, exist_ok=True)
        result_path.write_text(
            "".join(json.dumps(record, sort_keys=True) + "\n" for record in records),
            encoding="utf-8",
        )
        print(json.dumps({"result": str(result_path), "entry_point_probes": len(records)}))
        return 0
    single_dir = Path(args.result_dir).resolve() / _spec_slug(spec)
    record = probe_spec(spec, single_dir, tapenade, fortad, args.timeout)
    if args.result:
        _write_record(Path(args.result), record)
    elif not args.verbose:
        print(json.dumps({key: record[key] for key in ("case_path", "status", "entry_point", "result_dir")}))
    else:
        print(json.dumps(record, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    main()
