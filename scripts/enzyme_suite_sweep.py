#!/usr/bin/env python3
"""Shared parsing, statistics, and provenance helpers for the Enzyme sweep.

The timing executable writes measurements.  This module handles the pieces that
must remain deterministic and easy to test without the Enzyme or Tapenade
toolchains: size-list parsing, trial summaries, schema validation, and the
provenance sidecar.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import platform
import shutil
import socket
import statistics
import subprocess
import sys
from pathlib import Path
from typing import Iterable, Sequence


DEFAULT_SIZES = (100, 1_000, 10_000, 100_000, 1_000_000)
DEFAULT_WORKLOADS = ("euler", "rk4", "lstm", "ba", "bruss")
MEASURED_ENGINES = ("fortad", "enzyme", "tapenade", "fortad-grad", "primal")
DEFAULT_TRIALS = 7
RESULT_SCHEMA = "enzyme-suite-sweep-v2"
GAP_SCHEMA = "enzyme-suite-sweep-gaps-v1"


def parse_sizes(value: str | None) -> list[int]:
    """Parse a comma-separated positive size list without silently changing it."""

    if value is None or not value.strip():
        return list(DEFAULT_SIZES)
    result: list[int] = []
    for raw in value.split(","):
        token = raw.strip()
        if not token:
            raise ValueError("size list contains an empty item")
        try:
            size = int(token, 10)
        except ValueError as exc:
            raise ValueError(f"invalid problem size: {token!r}") from exc
        if size <= 0:
            raise ValueError(f"problem sizes must be positive: {size}")
        if size in result:
            raise ValueError(f"problem size repeated: {size}")
        result.append(size)
    return result


def parse_workloads(value: str | None) -> list[str]:
    """Parse a workload list while preserving its requested order."""

    if value is None or not value.strip() or value.strip().lower() == "all":
        return list(DEFAULT_WORKLOADS)
    result: list[str] = []
    allowed = set(DEFAULT_WORKLOADS)
    for raw in value.split(","):
        workload = raw.strip().lower()
        if not workload:
            raise ValueError("workload list contains an empty item")
        if workload not in allowed:
            raise ValueError(f"unknown workload: {workload!r}")
        if workload in result:
            raise ValueError(f"workload repeated: {workload}")
        result.append(workload)
    return result


def summarize(samples: Sequence[float]) -> dict[str, float | int]:
    """Return robust summary statistics for one engine's timed trials."""

    if not samples:
        raise ValueError("at least one timing sample is required")
    values = [float(sample) for sample in samples]
    if any(value < 0 for value in values):
        raise ValueError("timing samples must be non-negative")
    return {
        "trials": len(values),
        "median": statistics.median(values),
        "min": min(values),
        "max": max(values),
    }


def result_time_field(row: dict[str, str]) -> str:
    """Select the median field while retaining compatibility with old CSVs."""

    if row.get("seconds_median"):
        return "seconds_median"
    if row.get("seconds_total"):
        return "seconds_total"
    raise ValueError("result row has no seconds_median or seconds_total field")


def result_rate_field(row: dict[str, str]) -> str:
    if row.get("ns_per_input_median"):
        return "ns_per_input_median"
    if row.get("ns_per_input"):
        return "ns_per_input"
    raise ValueError("result row has no ns_per_input_median or ns_per_input field")


def validate_result_rows(rows: Iterable[dict[str, str]], sizes: Sequence[int]) -> None:
    """Validate behavioral invariants of a completed sweep result."""

    validate_measurement_matrix(rows, sizes)


def validate_measurement_matrix(
    rows: Iterable[dict[str, str]],
    sizes: Sequence[int],
    workloads: Sequence[str] | None = None,
) -> None:
    """Validate a complete workload/engine/size matrix and its arithmetic."""

    expected_sizes = set(sizes)
    expected_workloads = set(workloads or DEFAULT_WORKLOADS)
    expected_engines = set(MEASURED_ENGINES)
    required = {
        "workload",
        "engine",
        "problem_size",
        "input_count",
        "repetitions",
        "trials",
        "seconds_median",
        "seconds_min",
        "seconds_max",
        "ns_per_input_median",
        "ns_per_input_min",
        "ns_per_input_max",
        "timing_clock",
        "run_id",
        "provenance_file",
    }
    rows = list(rows)
    if not rows:
        raise ValueError("sweep result is empty")
    seen: set[tuple[str, str, int]] = set()
    input_counts: dict[tuple[str, int], int] = {}
    for row in rows:
        missing = required - row.keys()
        if missing:
            raise ValueError(f"result row is missing fields: {sorted(missing)}")
        workload = row["workload"]
        engine = row["engine"]
        if workload not in expected_workloads:
            raise ValueError(f"unexpected workload: {workload}")
        if engine not in expected_engines:
            raise ValueError(f"unexpected engine: {engine}")
        size = int(row["problem_size"])
        if size not in expected_sizes:
            raise ValueError(f"unexpected problem size: {size}")
        key = (workload, engine, size)
        if key in seen:
            raise ValueError(f"duplicate measurement row: {key}")
        seen.add(key)
        input_count = int(row["input_count"])
        if input_count <= 0:
            raise ValueError("input_count must be positive")
        previous_input_count = input_counts.setdefault((workload, size), input_count)
        if input_count != previous_input_count:
            raise ValueError(f"input_count changed within workload: {workload}")
        repetitions = int(row["repetitions"])
        if repetitions <= 0:
            raise ValueError("input_count and repetitions must be positive")
        trials = int(row["trials"])
        if trials <= 0:
            raise ValueError("trials must be positive")
        median = float(row["seconds_median"])
        low = float(row["seconds_min"])
        high = float(row["seconds_max"])
        if not (0 <= low <= median <= high):
            raise ValueError("seconds min, median, and max are not ordered")
        rate_median = float(row["ns_per_input_median"])
        rate_low = float(row["ns_per_input_min"])
        rate_high = float(row["ns_per_input_max"])
        if not (0 <= rate_low <= rate_median <= rate_high):
            raise ValueError("normalized timing min, median, and max are not ordered")
        denominator = float(repetitions * input_count)
        for seconds, rate in (
            (median, rate_median),
            (low, rate_low),
            (high, rate_high),
        ):
            expected_rate = seconds * 1.0e9 / denominator
            if abs(rate - expected_rate) > max(1.0e-6, abs(expected_rate) * 2.0e-5):
                raise ValueError("normalized timing does not match seconds/input_count")
        if row["timing_clock"] != "system_clock_wall":
            raise ValueError("sweep rows must identify the wall-clock source")
    expected = {
        (workload, engine, size)
        for workload in expected_workloads
        for engine in expected_engines
        for size in expected_sizes
    }
    if seen != expected:
        missing = sorted(expected - seen)
        extra = sorted(seen - expected)
        raise ValueError(f"measurement matrix mismatch; missing={missing}, extra={extra}")


def validate_measurement_points(
    rows: Iterable[dict[str, str]],
    sizes_by_workload: dict[str, Sequence[int]],
) -> None:
    """Validate complete engine rows for a possibly partial size matrix."""

    rows = list(rows)
    for workload, sizes in sizes_by_workload.items():
        subset = [row for row in rows if row["workload"] == workload]
        validate_measurement_matrix(subset, sizes, [workload])


def validate_gap_rows(
    rows: Iterable[dict[str, str]],
    sizes: Sequence[int],
    requested_workloads: Sequence[str],
) -> None:
    """Validate explicit, per-size records for every unavailable measurement."""

    required = {"workload", "engine", "problem_size", "status", "reason", "run_id", "provenance_file"}
    expected_sizes = set(sizes)
    expected_workloads = set(requested_workloads)
    seen: set[tuple[str, str, int]] = set()
    for row in rows:
        missing = required - row.keys()
        if missing:
            raise ValueError(f"gap row is missing fields: {sorted(missing)}")
        workload = row["workload"]
        if workload not in expected_workloads:
            raise ValueError(f"gap row has unexpected workload: {workload}")
        size = int(row["problem_size"])
        if size not in expected_sizes:
            raise ValueError(f"gap row has unexpected problem size: {size}")
        if row["status"] != "unavailable":
            raise ValueError("gap rows must use status=unavailable")
        if not row["reason"].strip():
            raise ValueError("gap row must include a reason")
        key = (workload, row["engine"], size)
        if key in seen:
            raise ValueError(f"duplicate gap row: {key}")
        seen.add(key)


def validate_coverage(
    measurement_rows: Iterable[dict[str, str]],
    gap_rows: Iterable[dict[str, str]],
    sizes: Sequence[int],
    requested_workloads: Sequence[str],
) -> None:
    """Require every requested workload to be measured or explicitly gapped."""

    measured = {
        (row["workload"], row["engine"], int(row["problem_size"]))
        for row in measurement_rows
        if row["engine"] in ("fortad", "enzyme", "tapenade")
    }
    gaps = {
        (row["workload"], row["engine"], int(row["problem_size"]))
        for row in gap_rows
    }
    expected = {
        (workload, engine, size)
        for workload in requested_workloads
        for engine in ("fortad", "enzyme", "tapenade")
        for size in sizes
    }
    if (measured | gaps) != expected or measured & gaps:
        missing = sorted(expected - measured - gaps)
        extra = sorted((measured | gaps) - expected)
        overlap = sorted(measured & gaps)
        raise ValueError(f"coverage mismatch; missing={missing}, extra={extra}, overlap={overlap}")


def write_gaps(path: Path, rows: Iterable[dict[str, str]]) -> None:
    """Write the explicit measurement-gap artifact used beside a sweep."""

    import csv

    fields = (
        "workload",
        "engine",
        "problem_size",
        "status",
        "reason",
        "run_id",
        "provenance_file",
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows({field: row[field] for field in fields} for row in rows)


def _command_version(command: str) -> dict[str, str | bool]:
    resolved = shutil.which(command)
    if not resolved:
        return {"command": command, "available": False, "version": "missing"}
    for args in (("--version",), ("-version",), ("-V",)):
        try:
            completed = subprocess.run(
                [resolved, *args],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        text = (completed.stdout or completed.stderr).strip().splitlines()
        if text:
            return {"command": resolved, "available": True, "version": text[0][:500]}
    return {"command": resolved, "available": True, "version": "version command unavailable"}


def _git_revision(path: Path) -> str:
    try:
        completed = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "HEAD"],
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "unavailable"
    return completed.stdout.strip() if completed.returncode == 0 else "unavailable"


def _cpu_model() -> str:
    try:
        for line in Path("/proc/cpuinfo").read_text(encoding="utf-8").splitlines():
            if line.lower().startswith("model name"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or "unknown"


def _artifact_summary(root: Path) -> dict[str, int]:
    build = root / "build" / "enzyme_suite"
    totals = {"generated_source_bytes": 0, "object_bytes": 0, "llvm_ir_bytes": 0}
    if not build.is_dir():
        return totals
    for path in build.iterdir():
        if not path.is_file():
            continue
        if path.suffix == ".f90":
            totals["generated_source_bytes"] += path.stat().st_size
        elif path.suffix == ".o":
            totals["object_bytes"] += path.stat().st_size
        elif path.suffix == ".ll":
            totals["llvm_ir_bytes"] += path.stat().st_size
    executable = build / "bench"
    totals["executable_bytes"] = executable.stat().st_size if executable.is_file() else 0
    return totals


def make_metadata(
    root: Path,
    *,
    run_id: str,
    status: str,
    sizes: Sequence[int],
    workloads: Sequence[str],
    measured_workloads: Sequence[str],
    trials: int,
    repetitions: str,
    output: str,
    gap_file: str,
    provenance_file: str,
    peak_rss_kb: int | None = None,
    requested_affinity: str = "unbound",
    missing_tools: Sequence[str] = (),
) -> dict:
    """Build the complete sidecar record without claiming a measurement."""

    fortad_repo = Path(os.environ.get("FORTAD_REPO", str(root.parent / "fortad")))
    tools = {
        key: _command_version(os.environ.get(env, default))
        for key, env, default in (
            ("flang", "FLANG", "flang"),
            ("clang", "CLANG", "clang"),
            ("opt", "OPT", "opt"),
            ("llvm_link", "LLVM_LINK", "llvm-link"),
            ("docker", "DOCKER", "docker"),
            ("time", "TIME", "/usr/bin/time"),
        )
    }
    image = os.environ.get(
        "TAPENADE_IMAGE",
        "registry.gitlab.inria.fr/tapenade/tapenade@sha256:1426f9f4fca94ccf665c96704886cf0595d806ca88e9fa63101a015dd62a46af",
    )
    affinity = requested_affinity
    if affinity == "unbound":
        try:
            affinity = ",".join(str(cpu) for cpu in sorted(os.sched_getaffinity(0)))
        except (AttributeError, OSError):
            affinity = "unavailable"
    artifacts = _artifact_summary(root) if status == "complete" else {}
    return {
        "schema_version": RESULT_SCHEMA,
        "gap_schema_version": GAP_SCHEMA,
        "status": status,
        "run_id": run_id,
        "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "bench_commit": _git_revision(root),
        "fortad_commit": _git_revision(fortad_repo),
        "host": {
            "hostname": socket.gethostname(),
            "system": platform.platform(),
            "kernel": platform.release(),
            "cpu_model": _cpu_model(),
            "logical_cpus": os.cpu_count(),
        },
        "toolchain": tools,
        "tapenade_image": image,
        "enzyme_plugin": os.environ.get(
            "ENZYME_PLUGIN", str(Path.home() / "code/enzyme/install-llvm22/lib/LLVMEnzyme-22.so")
        ),
        "flags": {
            "flang": "-O3 -fPIC for LLVM IR, -O3 for Fortran objects and driver",
            "clang": "-O3 -fPIC for LLVM IR and derivative object",
            "llvm_link": "-S",
            "opt": "-passes=enzyme, then -O3",
            "tapenade": "-b -head <workload>(y)/(z)",
            "runtime": "no runtime flags beyond the compiler command above",
        },
        "problem_sizes": list(sizes),
        "requested_workloads": list(workloads),
        "measured_workloads": list(measured_workloads),
        "trials": trials,
        "repetitions": repetitions,
        "timing_clock": "system_clock_wall",
        "provenance_file": provenance_file,
        "affinity": {
            "requested": requested_affinity,
            "effective_process_cpus": affinity,
            "launcher": "taskset" if requested_affinity != "unbound" else "inherited",
        },
        "output": output,
        "gap_file": gap_file,
        "peak_rss_kb": peak_rss_kb,
        "artifacts": artifacts,
        "missing_tools": list(missing_tools),
    }


def write_metadata(path: Path, metadata: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _record_command(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    sizes = parse_sizes(args.sizes)
    metadata = make_metadata(
        root,
        run_id=args.run_id,
        status=args.status,
        sizes=sizes,
        workloads=parse_workloads(args.workloads),
        measured_workloads=parse_workloads(args.measured_workloads) if args.measured_workloads else [],
        trials=args.trials,
        repetitions=args.repetitions,
        output=args.output,
        gap_file=args.gap_file,
        provenance_file=args.provenance_file,
        peak_rss_kb=args.peak_rss_kb,
        requested_affinity=args.affinity,
        missing_tools=args.missing_tool,
    )
    write_metadata(Path(args.provenance_file), metadata)
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    record = subparsers.add_parser("record", help="write a provenance sidecar")
    record.add_argument("--root", required=True)
    record.add_argument("--run-id", required=True)
    record.add_argument("--status", required=True, choices=("dry-run", "complete", "failed"))
    record.add_argument("--sizes", default=None)
    record.add_argument("--workloads", default=None)
    record.add_argument("--measured-workloads", default=None)
    record.add_argument("--trials", type=int, default=DEFAULT_TRIALS)
    record.add_argument("--repetitions", default="auto")
    record.add_argument("--output", required=True)
    record.add_argument("--gap-file", required=True)
    record.add_argument("--provenance-file", required=True)
    record.add_argument("--peak-rss-kb", type=int, default=None)
    record.add_argument("--affinity", default="unbound")
    record.add_argument("--missing-tool", action="append", default=[])
    record.set_defaults(handler=_record_command)
    args = parser.parse_args(argv)
    return args.handler(args)


if __name__ == "__main__":
    sys.exit(main())
