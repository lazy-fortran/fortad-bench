#!/usr/bin/env bash
# Build and run the same executable across the Enzyme/Tapenade/FortAD suite.
# Use --dry-run when one of the external toolchains is unavailable. A dry run
# records the requested experiment and missing tools, but writes no timings.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

sizes=${FORTAD_SWEEP_NS:-100,1000,10000,100000,1000000}
trials=${FORTAD_SWEEP_TRIALS:-7}
reps=${FORTAD_SWEEP_REPS:-auto}
affinity=${FORTAD_SWEEP_AFFINITY:-unbound}
dry_run=0

usage() {
    cat <<'EOF'
usage: scripts/run_enzyme_suite_sweep.sh [--dry-run] [--sizes LIST]
       [--trials COUNT] [--reps COUNT|auto] [--affinity CPU_LIST]

The default sizes are 100,1000,10000,100000,1000000. A completed run writes
results/enzyme_suite_sweep.csv and its provenance JSON sidecar. --dry-run
records tool availability and the requested protocol without measurements.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=1; shift ;;
        --sizes) sizes=${2:?--sizes needs a comma-separated list}; shift 2 ;;
        --trials) trials=${2:?--trials needs a positive integer}; shift 2 ;;
        --reps) reps=${2:?--reps needs COUNT or auto}; shift 2 ;;
        --affinity) affinity=${2:?--affinity needs a CPU list}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

python3 - "$sizes" "$trials" "$reps" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_sizes

parse_sizes(sys.argv[1])
trials = int(sys.argv[2])
if trials <= 0:
    raise SystemExit("--trials must be positive")
if sys.argv[3] != "auto" and int(sys.argv[3]) <= 0:
    raise SystemExit("--reps must be auto or positive")
PY

run_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
output="results/enzyme_suite_sweep.csv"
provenance="results/enzyme_suite_sweep.${run_id}.json"
missing=()
for tool in "${FLANG:-flang}" "${CLANG:-clang}" "${OPT:-opt}" "${LLVM_LINK:-llvm-link}" docker; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing+=("$tool")
    fi
done
if [[ ! -f "${ENZYME_PLUGIN:-$HOME/code/enzyme/install-llvm22/lib/LLVMEnzyme-22.so}" ]]; then
    missing+=("Enzyme plugin")
fi
if [[ "$reps" == auto ]]; then
    reps_for_metadata=auto
else
    reps_for_metadata=$reps
fi

record_metadata() {
    local status=$1
    local peak=${2:-}
    local args=(
        record --root "$root" --run-id "$run_id" --status "$status"
        --sizes "$sizes" --trials "$trials" --repetitions "$reps_for_metadata"
        --output "$output" --provenance-file "$provenance" --affinity "$affinity"
    )
    if [[ -n "$peak" ]]; then args+=(--peak-rss-kb "$peak"); fi
    for tool in "${missing[@]}"; do args+=(--missing-tool "$tool"); done
    python3 scripts/enzyme_suite_sweep.py "${args[@]}"
}

if ((dry_run)); then
    record_metadata dry-run
    printf 'dry-run: no timings written\nprovenance: %s\n' "$provenance"
    if ((${#missing[@]})); then
        printf 'missing: %s\n' "${missing[*]}"
    else
        echo 'toolchain check: all required commands found'
    fi
    exit 0
fi

if ((${#missing[@]})); then
    record_metadata failed
    printf 'cannot run sweep, missing: %s\n' "${missing[*]}" >&2
    printf 'dry-run metadata: %s\n' "$provenance" >&2
    exit 1
fi

export FORTAD_SWEEP_NS="$sizes"
export FORTAD_SWEEP_TRIALS="$trials"
export FORTAD_SWEEP_OUTPUT="$output"
export FORTAD_SWEEP_RUN_ID="$run_id"
export FORTAD_SWEEP_METADATA="$provenance"
if [[ "$reps" != auto ]]; then
    export FORTAD_SWEEP_REPS="$reps"
else
    export FORTAD_SWEEP_REPS=0
fi

./scripts/build_enzyme_suite.sh
time_log=$(mktemp)
trap 'rm -f "$time_log"' EXIT
if [[ "$affinity" == unbound ]]; then
    /usr/bin/time -v build/enzyme_suite/bench 2>"$time_log"
else
    taskset --cpu-list "$affinity" /usr/bin/time -v build/enzyme_suite/bench 2>"$time_log"
fi
peak_rss=$(awk -F: '/Maximum resident set size/ {gsub(/^[ \t]+/, "", $2); print $2}' "$time_log")
record_metadata complete "${peak_rss:-}"
python3 - <<'PY'
import csv
from pathlib import Path
import sys
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_sizes, validate_result_rows

rows = list(csv.DictReader(Path("results/enzyme_suite_sweep.csv").open(encoding="utf-8")))
validate_result_rows(rows, parse_sizes(__import__("os").environ["FORTAD_SWEEP_NS"]))
print(f"validated {len(rows)} sweep rows")
PY
printf 'results: %s\nprovenance: %s\n' "$output" "$provenance"
