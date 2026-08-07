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

The queue mode writes one JSON object per probe to a shard-specific JSONL file
and keeps generated products under the selected result directory. The pinned
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
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "upstream" / "tapenade"
QUEUE = ROOT / "docs" / "corpora" / "tapenade-fortran-queue.jsonl"
STATIC = ROOT / "docs" / "corpora" / "tapenade-static.jsonl"
TAPENADE_REVISION = "e59864cab441d4175df75383b3ff58c3dcd26df9"
FIXED_SUFFIXES = {".f", ".for", ".ftn", ".f77"}
FORTRAN_SUFFIXES = FIXED_SUFFIXES | {".f90", ".f95", ".f03", ".f08", ".f18", ".f2k"}
GENERATED_NAME = re.compile(
    r"(?:_aab|_aad|_b|_d|_p|_dv|_fwd|_bwd|_adj|_tangent)$", re.IGNORECASE
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
    candidate_key: str | None = None
    queue_category: str | None = None
    dependency_hints: tuple[str, ...] = ()
    source_candidates: tuple[str, ...] = ()
    entry_point_candidates: tuple[str, ...] = ()
    source_error: str | None = None


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
        (path for path in case.iterdir() if path.is_file() and path.suffix.lower() in FORTRAN_SUFFIXES),
        key=lambda path: path.name.casefold(),
    )


def _source_priority(path: Path) -> tuple[int, int, str]:
    name = path.name.lower()
    stem = path.stem.lower()
    generated = 1 if GENERATED_NAME.search(stem) else 0
    if name in {"program.f", "program.f90"}:
        return (generated, 0, name)
    if name.startswith("program."):
        return (generated, 1, name)
    return (generated, 2, name)


def _select_source(case: Path, requested: str | None = None) -> Path:
    if requested:
        requested_path = Path(requested)
        if requested_path.is_absolute() or ".." in requested_path.parts:
            raise ValueError(f"manifest source is not a safe upstream-relative path: {requested}")
        candidate = UPSTREAM / requested_path
        if not candidate.is_file():
            raise ValueError(f"manifest source is not present: {requested}")
        try:
            candidate.relative_to(case)
        except ValueError as error:
            raise ValueError(f"manifest source is outside its case: {requested}") from error
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
    return sorted(names)


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
        source_candidates=(str(source.relative_to(UPSTREAM)).replace("\\", "/"),),
        entry_point_candidates=(_entry_name(entry),) if _entry_name(entry) else (),
    )


def spec_from_case(case_path: str) -> ProbeSpec:
    specs = specs_from_case(case_path)
    return specs[0]


def specs_from_case(case_path: str, all_entries: bool = False) -> list[ProbeSpec]:
    case_path = case_path.replace("\\", "/").strip("/")
    requested_case = UPSTREAM / case_path
    if requested_case.is_file():
        case = requested_case.parent
        source = _select_source(case, case_path)
        hint_path = case_path
    elif requested_case.is_dir():
        case = requested_case
        source = _select_source(case)
        hint_path = case_path
    else:
        raise ValueError(f"upstream case directory is not present: {case_path}")
    source_name = str(source.relative_to(UPSTREAM)).replace("\\", "/")
    source_candidates = tuple(
        str(path.relative_to(UPSTREAM)).replace("\\", "/")
        for path in _fortran_sources(case)
    )
    hints = _canonical_hints(hint_path, source_name)
    entries = (hints or [None]) if all_entries else (hints[:1] if len(hints) == 1 else [None])
    output_case_path = str(case.relative_to(UPSTREAM)).replace("\\", "/")
    return [
        ProbeSpec(
            case_path=output_case_path,
            source=source_name,
            entry_point=entry,
            independent=(),
            dependent=None,
            modes=("parser", "forward", "reverse"),
            source_candidates=source_candidates,
            entry_point_candidates=tuple(hints),
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
        "candidate_key": spec.candidate_key,
        "case_path": spec.case_path,
        "source": spec.source,
        "source_candidates": list(spec.source_candidates),
        "entry_point": spec.entry_point,
        "entry_point_candidates": list(spec.entry_point_candidates),
        "independent": list(spec.independent),
        "dependent": spec.dependent,
        "modes": list(spec.modes),
        "manifest": spec.manifest,
        "queue_category": spec.queue_category,
        "dependency_risk": bool(spec.dependency_hints),
        "dependency_hints": list(spec.dependency_hints),
        "upstream_revision": _git_revision(UPSTREAM),
        "expected_upstream_revision": TAPENADE_REVISION,
        "fortad_revision": _git_revision(_git_root_for_executable(fortad)) if fortad else None,
        "selection": "explicit" if spec.manifest or spec.entry_point else "static-unambiguous",
        "result_dir": str(result_dir),
        "probes": {},
    }
    if spec.source_error:
        record["status"] = "source-selection-error"
        record["reason"] = spec.source_error
        return record
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
    prefix = _path_slug(spec.candidate_key) if spec.candidate_key else _path_slug(spec.case_path)
    suffix = f"__{_path_slug(spec.entry_point)}" if spec.entry_point else ""
    return prefix + suffix


def _queue_specs(args: argparse.Namespace, *, partition: bool = True) -> list[ProbeSpec]:
    rows = _load_jsonl(Path(args.queue_file))
    rows = [row for row in rows if args.include_classified or row.get("path")]
    if args.pure_fortran:
        rows = [row for row in rows if row.get("language") == "fortran"]
    rows.sort(key=lambda row: (str(row.get("component", "")), str(row["path"])))
    if partition:
        rows = [
            row for index, row in enumerate(rows)
            if index % args.shard_count == args.shard_index
        ]
    if args.limit is not None:
        rows = rows[: args.limit]
    specs: list[ProbeSpec] = []
    for row in rows:
        candidate_key = f"{row.get('component', '')}:{row['path']}"
        dependency_hints = tuple(sorted({str(item) for item in row.get("unresolved_include_hints", [])}))
        try:
            discovered = specs_from_case(row["path"], all_entries=True)
        except ValueError as error:
            discovered = [
                ProbeSpec(
                    case_path=row["path"],
                    source="",
                    entry_point=None,
                    independent=(),
                    dependent=None,
                    modes=(),
                    source_candidates=tuple(sorted(str(item) for item in row.get("source_files", []))),
                    source_error=str(error),
                )
            ]
        specs.extend(
            replace(
                spec,
                candidate_key=candidate_key,
                queue_category=str(row.get("queue_category", "")) or None,
                dependency_hints=dependency_hints,
            )
            for spec in discovered
        )
    return specs


def _spec_key(spec: ProbeSpec) -> tuple[str, str, str]:
    return (spec.candidate_key or spec.case_path, spec.source, spec.entry_point or "")


def _record_key(record: dict[str, Any]) -> tuple[str, str, str]:
    return (
        str(record.get("candidate_key") or record.get("case_path", "")),
        str(record.get("source", "")),
        str(record.get("entry_point") or ""),
    )


def _record_sort_key(record: dict[str, Any]) -> tuple[str, str, str]:
    return _record_key(record)


def _load_records(path: Path) -> dict[tuple[str, str, str], dict[str, Any]]:
    if not path.is_file():
        return {}
    records: dict[tuple[str, str, str], dict[str, Any]] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
        for line in lines:
            if not line.strip():
                continue
            record = json.loads(line)
            key = _record_key(record)
            if key in records:
                raise ValueError(f"duplicate probe record key {key}")
            records[key] = record
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read probe records {path}: {error}") from error
    return records


def _write_records(path: Path, records: Iterable[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rendered = "".join(
        json.dumps(record, sort_keys=True) + "\n"
        for record in sorted(records, key=_record_sort_key)
    )
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(rendered, encoding="utf-8")
    os.replace(temporary, path)


def _queue_result_path(args: argparse.Namespace, result_dir: Path) -> Path:
    if args.result:
        return Path(args.result).resolve()
    if args.shard_count == 1:
        return result_dir / "results.jsonl"
    return result_dir / f"results.shard-{args.shard_index:04d}-of-{args.shard_count:04d}.jsonl"


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
    source.add_argument("--case", help="relative case directory or source file under upstream/tapenade")
    source.add_argument("--queue", action="store_true", help="probe the queued corpus candidates")
    parser.add_argument("--entry-point", help="explicit procedure name or NAME(args)")
    parser.add_argument(
        "--all-entry-points",
        action="store_true",
        help="probe every canonical source procedure for a single --case",
    )
    parser.add_argument("--queue-file", dest="queue_file", default=str(QUEUE), help=argparse.SUPPRESS)
    parser.add_argument("--result", help="JSON output path (single case or queue shard)")
    parser.add_argument("--result-dir", default="/var/tmp/fortad-tapenade-probes")
    parser.add_argument("--fortad", help="FortAD executable; defaults to FORTAD_CLI or the local build")
    parser.add_argument("--tapenade", help="Tapenade executable; defaults to TAPENADE_CLI or upstream/bin/tapenade")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--shard-count", type=int, default=1)
    parser.add_argument("--shard-index", type=int, default=0)
    parser.add_argument("--limit", type=int)
    parser.add_argument(
        "--pure-fortran",
        action="store_true",
        help="in queue mode, exclude mixed-language candidates",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="in queue mode, retain completed records in this shard output",
    )
    parser.add_argument(
        "--merge-input",
        action="append",
        type=Path,
        default=[],
        help="in queue mode, merge completed shard JSONL files deterministically",
    )
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
        result_dir = Path(args.result_dir).resolve()
        if args.merge_input:
            if args.resume:
                raise SystemExit("--resume cannot be combined with --merge-input")
            specs = _queue_specs(args, partition=False)
            expected = {_spec_key(spec) for spec in specs}
            merged: dict[tuple[str, str, str], dict[str, Any]] = {}
            for input_path in args.merge_input:
                for key, record in _load_records(input_path).items():
                    if key in merged:
                        raise SystemExit(f"duplicate probe record across shards: {key}")
                    merged[key] = record
            observed = set(merged)
            if observed != expected:
                missing = len(expected - observed)
                extra = len(observed - expected)
                raise SystemExit(
                    f"probe shards do not cover queue: missing={missing}, extra={extra}"
                )
            result_path = _queue_result_path(args, result_dir)
            _write_records(result_path, merged.values())
            print(json.dumps({
                "result": str(result_path),
                "cases": len({record["case_path"] for record in merged.values()}),
                "entry_point_probes": len(merged),
                "merged_shards": len(args.merge_input),
            }))
            return 0

        specs = _queue_specs(args)
        result_path = _queue_result_path(args, result_dir)
        records = _load_records(result_path) if args.resume else {}
        expected = {_spec_key(spec) for spec in specs}
        unexpected = set(records) - expected
        if unexpected:
            raise SystemExit(
                f"resume output contains records outside this shard: {len(unexpected)}"
            )
        pending = [spec for spec in specs if _spec_key(spec) not in records]

        def run(spec: ProbeSpec) -> dict[str, Any]:
            return probe_spec(
                spec,
                result_dir / _spec_slug(spec),
                tapenade,
                fortad,
                args.timeout,
            )

        if not args.resume or records:
            _write_records(result_path, records.values())
        if args.jobs > 1:
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
                futures = {pool.submit(run, spec): spec for spec in pending}
                for future in concurrent.futures.as_completed(futures):
                    record = future.result()
                    records[_record_key(record)] = record
                    _write_records(result_path, records.values())
        else:
            for spec in pending:
                record = run(spec)
                records[_record_key(record)] = record
                _write_records(result_path, records.values())
        print(json.dumps({
            "result": str(result_path),
            "cases": len({record["case_path"] for record in records.values()}),
            "entry_point_probes": len(records),
            "processed": len(pending),
            "resumed": len(records) - len(pending),
            "shard_index": args.shard_index,
            "shard_count": args.shard_count,
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
