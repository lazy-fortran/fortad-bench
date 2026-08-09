#!/usr/bin/env bash
# Build and run the common Enzyme/Tapenade/FortAD suite. The timing CSV contains
# only complete three-engine workload matrices; unavailable pairs go to the gap
# CSV with one row per requested problem size.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

sizes=${FORTAD_SWEEP_NS:-100,1000,10000,100000,1000000}
workloads=${FORTAD_SWEEP_WORKLOADS:-all}
trials=${FORTAD_SWEEP_TRIALS:-7}
reps=${FORTAD_SWEEP_REPS:-auto}
affinity=${FORTAD_SWEEP_AFFINITY:-unbound}
dry_run=0

usage() {
    cat <<'EOF'
usage: scripts/run_enzyme_suite_sweep.sh [--dry-run] [--sizes LIST]
       [--workloads LIST|all] [--trials COUNT] [--reps COUNT|auto]
       [--affinity CPU_LIST]

The default sizes are 100,1000,10000,100000,1000000. A completed run writes
results/enzyme_suite_sweep.csv, results/enzyme_suite_sweep_gaps.csv, and its
provenance JSON sidecar. --dry-run records tool availability and the requested
protocol without measurements.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=1; shift ;;
        --sizes) sizes=${2:?--sizes needs a comma-separated list}; shift 2 ;;
        --workloads) workloads=${2:?--workloads needs a comma-separated list}; shift 2 ;;
        --trials) trials=${2:?--trials needs a positive integer}; shift 2 ;;
        --reps) reps=${2:?--reps needs COUNT or auto}; shift 2 ;;
        --affinity) affinity=${2:?--affinity needs a CPU list}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

python3 - "$sizes" "$workloads" "$trials" "$reps" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_sizes, parse_workloads

parse_sizes(sys.argv[1])
parse_workloads(sys.argv[2])
trials = int(sys.argv[3])
if trials <= 0:
    raise SystemExit("--trials must be positive")
if sys.argv[4] != "auto" and int(sys.argv[4]) <= 0:
    raise SystemExit("--reps must be auto or positive")
PY

run_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
output="results/enzyme_suite_sweep.csv"
gap_file="results/enzyme_suite_sweep_gaps.csv"
provenance="results/enzyme_suite_sweep.${run_id}.json"
missing=()
for tool in "${FLANG:-flang}" "${CLANG:-clang}" "${OPT:-opt}" "${LLVM_LINK:-llvm-link}" "${DOCKER:-docker}" timeout; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing+=("$tool")
    fi
done
if command -v "${DOCKER:-docker}" >/dev/null 2>&1 && ! "${DOCKER:-docker}" info >/dev/null 2>&1; then
    missing+=("Docker daemon")
fi
default_plugin=$(python3 -c 'from pathlib import Path; print(Path.home() / "code/enzyme/install-llvm22/lib/LLVMEnzyme-22.so")')
plugin=${ENZYME_PLUGIN:-$default_plugin}
if [[ ! -f "$plugin" ]]; then
    missing+=("Enzyme plugin: $plugin")
fi
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
if ! find "$fortad_repo/build" -name fortad -type f -perm -u+x -print -quit 2>/dev/null | grep -q .; then
    missing+=("FortAD executable under $fortad_repo/build")
fi
if [[ "$reps" == auto ]]; then
    reps_for_metadata=auto
else
    reps_for_metadata=$reps
fi

record_metadata() {
    local status=$1
    local peak=${2:-}
    local measured=${3:-}
    local args=(
        record --root "$root" --run-id "$run_id" --status "$status"
        --sizes "$sizes" --workloads "$workloads" --measured-workloads "$measured"
        --trials "$trials" --repetitions "$reps_for_metadata"
        --output "$output" --gap-file "$gap_file"
        --provenance-file "$provenance" --affinity "$affinity"
    )
    if [[ -n "$peak" ]]; then args+=(--peak-rss-kb "$peak"); fi
    for tool in "${missing[@]}"; do args+=(--missing-tool "$tool"); done
    python3 scripts/enzyme_suite_sweep.py "${args[@]}"
}

write_global_gaps() {
    local reason=$1
    python3 - "$sizes" "$workloads" "$run_id" "$provenance" "$gap_file" "$reason" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_sizes, parse_workloads, write_gaps

sizes = parse_sizes(sys.argv[1])
workloads = parse_workloads(sys.argv[2])
reason = sys.argv[6]
rows = [
    {"workload": workload, "engine": engine, "problem_size": str(size),
     "status": "unavailable", "reason": reason, "run_id": sys.argv[3],
     "provenance_file": sys.argv[4]}
    for workload in workloads
    for engine in ("fortad", "enzyme", "tapenade")
    for size in sizes
]
write_gaps(Path(sys.argv[5]), rows)
PY
}

if ((dry_run)); then
    if ((${#missing[@]})); then
        write_global_gaps "toolchain unavailable: ${missing[*]}"
    else
        python3 - "$gap_file" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import write_gaps
write_gaps(Path(sys.argv[1]), [])
PY
    fi
    record_metadata dry-run
    printf 'dry-run: no timings written\nprovenance: %s\ngaps: %s\n' "$provenance" "$gap_file"
    if ((${#missing[@]})); then
        printf 'missing: %s\n' "${missing[*]}"
    else
        echo 'toolchain check: all required commands found'
    fi
    exit 0
fi

if ((${#missing[@]})); then
    write_global_gaps "toolchain unavailable: ${missing[*]}"
    record_metadata failed
    printf 'cannot run sweep, missing: %s\nprovenance: %s\ngaps: %s\n' "${missing[*]}" "$provenance" "$gap_file" >&2
    exit 1
fi

export FORTAD_SWEEP_NS="$sizes"
export FORTAD_SWEEP_WORKLOADS="$workloads"
export FORTAD_SWEEP_TRIALS="$trials"
export FORTAD_SWEEP_OUTPUT="$output"
export FORTAD_SWEEP_RUN_ID="$run_id"
export FORTAD_SWEEP_METADATA="$provenance"
export FORTAD_SWEEP_REQUESTED_WORKLOADS="$workloads"
if [[ "$reps" != auto ]]; then
    export FORTAD_SWEEP_REPS="$reps"
else
    export FORTAD_SWEEP_REPS=0
fi

if ! ./scripts/build_enzyme_suite.sh; then
    if [[ -f build/enzyme_suite/availability.csv ]]; then
        python3 - "$sizes" "$workloads" "$run_id" "$provenance" "$gap_file" <<'PY'
import csv
import sys
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_sizes, parse_workloads, write_gaps

sizes = parse_sizes(sys.argv[1])
requested = parse_workloads(sys.argv[2])
availability = list(csv.DictReader(Path("build/enzyme_suite/availability.csv").open(encoding="utf-8")))
status = {(item["workload"], item["engine"]): item for item in availability}
rows = []
for workload in requested:
    complete = all(status[(workload, engine)]["status"] == "ok"
                   for engine in ("fortad", "enzyme", "tapenade"))
    for engine in ("fortad", "enzyme", "tapenade"):
        item = status[(workload, engine)]
        if item["status"] == "ok" and complete:
            continue
        if item["status"] != "ok":
            reason = item["reason"]
        else:
            unavailable = [status[(workload, other)]["reason"]
                           for other in ("fortad", "enzyme", "tapenade")
                           if status[(workload, other)]["status"] != "ok"]
            reason = "not measured because the complete three-engine intersection is unavailable: " + "; ".join(unavailable)
        for size in sizes:
            rows.append({"workload": workload, "engine": engine,
                         "problem_size": str(size), "status": "unavailable",
                         "reason": reason, "run_id": sys.argv[3],
                         "provenance_file": sys.argv[4]})
write_gaps(Path(sys.argv[5]), rows)
PY
    else
        write_global_gaps "build failed before a comparable executable was produced"
    fi
    record_metadata failed
    printf 'build failed; provenance: %s; gaps: %s\n' "$provenance" "$gap_file" >&2
    exit 1
fi

runnable=$(python3 - "$workloads" <<'PY'
import csv
import sys
from collections import defaultdict
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_workloads

requested = parse_workloads(sys.argv[1])
status = defaultdict(dict)
for row in csv.DictReader(Path("build/enzyme_suite/availability.csv").open(encoding="utf-8")):
    status[row["workload"]][row["engine"]] = row["status"]
print(",".join(workload for workload in requested if all(
    status[workload].get(engine) == "ok"
    for engine in ("fortad", "enzyme", "tapenade")
)))
PY
)
python3 - "$sizes" "$workloads" "$run_id" "$provenance" "$gap_file" <<'PY'
import csv
import sys
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_sizes, parse_workloads, write_gaps

sizes = parse_sizes(sys.argv[1])
requested = parse_workloads(sys.argv[2])
availability = list(csv.DictReader(Path("build/enzyme_suite/availability.csv").open(encoding="utf-8")))
status = {(item["workload"], item["engine"]): item for item in availability}
rows = []
for workload in requested:
    complete = all(status[(workload, engine)]["status"] == "ok"
                   for engine in ("fortad", "enzyme", "tapenade"))
    for engine in ("fortad", "enzyme", "tapenade"):
        item = status[(workload, engine)]
        if item["status"] == "ok" and complete:
            continue
        if item["status"] != "ok":
            reason = item["reason"]
        else:
            unavailable = [status[(workload, other)]["reason"]
                           for other in ("fortad", "enzyme", "tapenade")
                           if status[(workload, other)]["status"] != "ok"]
            reason = "not measured because the complete three-engine intersection is unavailable: " + "; ".join(unavailable)
        for size in sizes:
            rows.append({"workload": workload, "engine": engine,
                         "problem_size": str(size), "status": "unavailable",
                         "reason": reason, "run_id": sys.argv[3],
                         "provenance_file": sys.argv[4]})
write_gaps(Path(sys.argv[5]), rows)
PY
if [[ -z "$runnable" ]]; then
    record_metadata failed
    write_global_gaps "no complete three-engine workload intersection"
    exit 1
fi
export FORTAD_SWEEP_WORKLOADS="$runnable"
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT
failure_file="$scratch_dir/failures.csv"
: > "$failure_file"
peak_rss=0
IFS=, read -r -a runnable_list <<< "$runnable"
IFS=, read -r -a size_list <<< "$sizes"
for workload in "${runnable_list[@]}"; do
    for size in "${size_list[@]}"; do
        sub_output="$scratch_dir/${workload}_${size}.csv"
        sub_time="$scratch_dir/${workload}_${size}.time"
        export FORTAD_SWEEP_NS="$size"
        export FORTAD_SWEEP_WORKLOADS="$workload"
        export FORTAD_SWEEP_OUTPUT="$sub_output"
        if [[ "$affinity" == unbound ]]; then
            if /usr/bin/time -v timeout --kill-after=5s 300s build/enzyme_suite/bench 2>"$sub_time"; then
                :
            else
                rc=$?
                printf '%s,%s,%s\n' "$workload" "$size" "$rc" >> "$failure_file"
            fi
        else
            if taskset --cpu-list "$affinity" /usr/bin/time -v timeout --kill-after=5s 300s \
                build/enzyme_suite/bench 2>"$sub_time"; then
                :
            else
                rc=$?
                printf '%s,%s,%s\n' "$workload" "$size" "$rc" >> "$failure_file"
            fi
        fi
        rss=$(awk -F: '/Maximum resident set size/ {gsub(/^[ \t]+/, "", $2); print $2}' "$sub_time")
        if [[ "$rss" =~ ^[0-9]+$ ]] && ((rss > peak_rss)); then peak_rss=$rss; fi
    done
done
python3 - "$scratch_dir" "$failure_file" "$sizes" "$workloads" "$run_id" "$provenance" "$output" "$gap_file" <<'PY'
import csv
import sys
from collections import defaultdict
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_sizes, parse_workloads, write_gaps

scratch = Path(sys.argv[1])
failures = {(row[0], int(row[1])): row[2] for row in csv.reader(Path(sys.argv[2]).open(encoding="utf-8"))}
sizes = parse_sizes(sys.argv[3])
requested = parse_workloads(sys.argv[4])
availability = {(row["workload"], row["engine"]): row for row in csv.DictReader(
    Path("build/enzyme_suite/availability.csv").open(encoding="utf-8"))}
by_point = defaultdict(list)
fieldnames = None
for path in sorted(scratch.glob("*.csv")):
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if fieldnames is None:
            fieldnames = reader.fieldnames
        for row in reader:
            by_point[(row["workload"], int(row["problem_size"]))].append(row)

measurement_rows = []
gap_rows = []
measured_sizes = defaultdict(list)
for workload in requested:
    build_complete = all(availability[(workload, engine)]["status"] == "ok"
                         for engine in ("fortad", "enzyme", "tapenade"))
    for size in sizes:
        point = (workload, size)
        point_rows = by_point.get(point, [])
        point_complete = {row["engine"] for row in point_rows} >= {
            "fortad", "enzyme", "tapenade", "fortad-grad", "primal"
        }
        if build_complete and point_complete and point not in failures:
            measurement_rows.extend(point_rows)
            measured_sizes[workload].append(size)
            continue
        runtime_reason = ""
        if point in failures:
            runtime_reason = f"benchmark process failed with exit status {failures[point]}"
        for engine in ("fortad", "enzyme", "tapenade"):
            item = availability[(workload, engine)]
            if item["status"] != "ok":
                reason = item["reason"]
            elif runtime_reason:
                reason = runtime_reason
            else:
                unavailable = [availability[(workload, other)]["reason"]
                               for other in ("fortad", "enzyme", "tapenade")
                               if availability[(workload, other)]["status"] != "ok"]
                reason = "not measured because the complete three-engine intersection is unavailable: " + "; ".join(unavailable)
            gap_rows.append({"workload": workload, "engine": engine,
                             "problem_size": str(size), "status": "unavailable",
                             "reason": reason, "run_id": sys.argv[5],
                             "provenance_file": sys.argv[6]})

if fieldnames is None or not measurement_rows:
    raise SystemExit("no complete measurement point was produced")
with Path(sys.argv[7]).open("w", encoding="utf-8", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(measurement_rows)
write_gaps(Path(sys.argv[8]), gap_rows)
Path(scratch / "measured_workloads").write_text(
    ",".join(workload for workload in requested if measured_sizes[workload] == sizes) + "\n",
    encoding="utf-8")
PY
measured=$(<"$scratch_dir/measured_workloads")
export FORTAD_SWEEP_NS="$sizes"
export FORTAD_SWEEP_WORKLOADS="$runnable"
python3 - "$scratch_dir" <<'PY'
import csv
import os
import sys
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import (
    parse_sizes,
    parse_workloads,
    validate_coverage,
    validate_gap_rows,
    validate_measurement_points,
)

sizes = parse_sizes(os.environ["FORTAD_SWEEP_NS"])
requested = parse_workloads(os.environ["FORTAD_SWEEP_REQUESTED_WORKLOADS"])
rows = list(csv.DictReader(Path("results/enzyme_suite_sweep.csv").open(encoding="utf-8")))
gaps = list(csv.DictReader(Path("results/enzyme_suite_sweep_gaps.csv").open(encoding="utf-8")))
points = {}
for row in rows:
    points.setdefault(row["workload"], set()).add(int(row["problem_size"]))
validate_measurement_points(rows, {workload: sorted(point_sizes) for workload, point_sizes in points.items()})
validate_gap_rows(gaps, sizes, requested)
validate_coverage(rows, gaps, sizes, requested)
print(f"validated {len(rows)} measurement rows and {len(gaps)} explicit gap rows")
PY
record_metadata complete "$peak_rss" "$measured"
printf 'results: %s\nprovenance: %s\ngaps: %s\n' "$output" "$provenance" "$gap_file"
