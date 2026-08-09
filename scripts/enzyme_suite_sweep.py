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
DEFAULT_TRIALS = 7
RESULT_SCHEMA = "enzyme-suite-sweep-v1"


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

    expected_sizes = set(sizes)
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
    seen_sizes: set[int] = set()
    for row in rows:
        missing = required - row.keys()
        if missing:
            raise ValueError(f"result row is missing fields: {sorted(missing)}")
        size = int(row["problem_size"])
        if size not in expected_sizes:
            raise ValueError(f"unexpected problem size: {size}")
        seen_sizes.add(size)
        if int(row["input_count"]) <= 0 or int(row["repetitions"]) <= 0:
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
        if row["timing_clock"] != "system_clock_wall":
            raise ValueError("sweep rows must identify the wall-clock source")
    if seen_sizes != expected_sizes:
        raise ValueError(f"result omitted requested sizes: {sorted(expected_sizes - seen_sizes)}")


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
    trials: int,
    repetitions: str,
    output: str,
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
        trials=args.trials,
        repetitions=args.repetitions,
        output=args.output,
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
    record.add_argument("--trials", type=int, default=DEFAULT_TRIALS)
    record.add_argument("--repetitions", default="auto")
    record.add_argument("--output", required=True)
    record.add_argument("--provenance-file", required=True)
    record.add_argument("--peak-rss-kb", type=int, default=None)
    record.add_argument("--affinity", default="unbound")
    record.add_argument("--missing-tool", action="append", default=[])
    record.set_defaults(handler=_record_command)
    args = parser.parse_args(argv)
    return args.handler(args)


if __name__ == "__main__":
    sys.exit(main())
