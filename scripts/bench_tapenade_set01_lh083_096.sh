#!/usr/bin/env bash
# Validate Tapenade set01 lh085/lh092 with fresh engine probes.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh083_096_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=72f8fe8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
compile_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/tranche-n-lh083-096-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
if manifest["runner"] != "scripts/bench_tapenade_set01_lh083_096.sh":
    raise SystemExit("tranche N runner mismatch")
if manifest["upstream_revision"] != "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("tranche N Tapenade revision mismatch")
cases = {case["id"]: case for case in manifest["case"]}
if set(cases) != {"lh085", "lh092"}:
    raise SystemExit("tranche N case set mismatch")
if any(case["classification"] != "runnable-ported" for case in cases.values()):
    raise SystemExit("tranche N cases must be runnable")
if cases["lh092"]["independent"] != ["a", "b"]:
    raise SystemExit("lh092 reverse contract must include both independent inputs")
PY

out=$(mktemp -d /var/tmp/ert/tapenade-set01-lh083-096.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade"
for case_id in lh085 lh092; do
    mkdir -p "$out/tapenade/$case_id/parser" \
        "$out/tapenade/$case_id/forward" "$out/tapenade/$case_id/reverse"
done

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
tapenade="$tapenade_repo/bin/tapenade"

compile_capture() {
    local source=$1 object=$2 status_file=$3 flags_name=$4
    local -a flags
    if test "$flags_name" = strict; then
        flags=("${strict_flags[@]}")
    else
        flags=("${compile_flags[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" \
        >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
}

declare -A proc=( [lh085]=bigexpr [lh092]=f1 )

for case_id in lh085 lh092; do
    upstream_dir="$tapenade_repo/nonRegressions/set01/$case_id"
    case_out="$out/tapenade/$case_id"
    compile_capture "$upstream_dir/program.f" "$case_out/upstream-primal.o" \
        "$case_out/upstream-primal.status" strict
    test "$(cat "$case_out/upstream-primal.status")" = 0

    tapenade_start=$(date +%s.%N)
    "$tapenade" -p -O "$case_out/parser" -o "${case_id}_p" \
        "$upstream_dir/program.f" >"$case_out/parser.stdout" \
        2>"$case_out/parser.stderr"
    "$tapenade" -d -root "${proc[$case_id]}" -O "$case_out/forward" \
        -o "${case_id}_d" "$upstream_dir/program.f" \
        >"$case_out/forward.stdout" 2>"$case_out/forward.stderr"
    "$tapenade" -b -root "${proc[$case_id]}" -O "$case_out/reverse" \
        -o "${case_id}_b" "$upstream_dir/program.f" \
        >"$case_out/reverse.stdout" 2>"$case_out/reverse.stderr"
    tapenade_stop=$(date +%s.%N)
    printf '%s\n' "$(awk -v a="$tapenade_start" -v b="$tapenade_stop" 'BEGIN {print b-a}')" \
        >"$case_out/tapenade_transform_seconds"

    parser_source="$case_out/parser/${case_id}_p_p.f"
    forward_source="$case_out/forward/${case_id}_d_d.f"
    reverse_source="$case_out/reverse/${case_id}_b_b.f"
    for generated in "$parser_source" "$forward_source" "$reverse_source"; do
        test -s "$generated"
        compile_capture "$generated" "$generated.o" "$generated.status" strict
        test "$(cat "$generated.status")" = 0
    done
done

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

fortad_start=$(date +%s.%N)
fortad_exec jvp v --proc set01_lh085 --name lh085_jvp \
    --module lh085_forward_ad --output "$out/lh085_forward.f90" \
    "$case_dir/lh085.f90" >"$out/lh085-forward.stdout" 2>"$out/lh085-forward.stderr"
fortad_exec vjp v --dep r1 --proc set01_lh085 --name lh085_vjp \
    --module lh085_reverse_ad --output "$out/lh085_reverse.f90" \
    "$case_dir/lh085.f90" >"$out/lh085-reverse.stdout" 2>"$out/lh085-reverse.stderr"
fortad_exec jvp a,b --proc set01_lh092 --name lh092_jvp \
    --module lh092_forward_ad --output "$out/lh092_forward.f90" \
    "$case_dir/lh092.f90" >"$out/lh092-forward.stdout" 2>"$out/lh092-forward.stderr"
fortad_exec vjp a,b --dep c --proc set01_lh092 --name lh092_vjp \
    --module lh092_reverse_ad --output "$out/lh092_reverse.f90" \
    "$case_dir/lh092.f90" >"$out/lh092-reverse.stdout" 2>"$out/lh092-reverse.stderr"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" 'BEGIN {print b-a}')

compile_start=$(date +%s.%N)
for source in "$case_dir/lh085.f90" "$case_dir/lh092.f90" \
    "$case_dir/hand_derivatives_lh085_092.f90" \
    "$out/lh085_forward.f90" "$out/lh085_reverse.f90" \
    "$out/lh092_forward.f90" "$out/lh092_reverse.f90"; do
    base=$(basename "$source" .f90)
    compile_capture "$source" "$out/$base.o" "$out/$base.status" normal
    test "$(cat "$out/$base.status")" = 0
done
compile_capture "$root/harness/bench_tapenade_set01_lh083_096.f90" \
    "$out/harness.o" "$out/harness.status" normal
test "$(cat "$out/harness.status")" = 0
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/hand_derivatives_lh085_092.o" "$out/lh085_forward.o" \
    "$out/lh085_reverse.o" "$out/lh092_forward.o" "$out/lh092_reverse.o" \
    "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" 'BEGIN {print b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'suite: Tapenade nonRegressions set01 tranche N (lh085, lh092)\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'tapenade_transform_seconds_total: %s\n' \
        "$(awk '{s += $1} END {print s}' "$out"/tapenade/*/tapenade_transform_seconds)"
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'generated_compile_seconds_total: %s\n' "$compile_seconds"
    printf 'upstream_exact_source_compile_statuses:\n'
    for status in "$out"/tapenade/*/upstream-primal.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated; '
    printf '%s\n' 'all generated sources compile under strict fixed-form flags'
    printf 'tapenade_generated_compile_statuses:\n'
    find "$out/tapenade" -name '*.f.status' -print | sort | while read -r status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'fortad_transform_compile_statuses:\n'
    for status in "$out"/*.status; do
        case "$status" in *harness.status) continue;; esac
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh085.f90 cases/tapenade-set01/lh092.f90 \
        cases/tapenade-set01/hand_derivatives_lh085_092.f90 \
        cases/tapenade-set01/tranche-n-lh083-096-manifest.toml \
        cases/tapenade-set01/tranche-n-lh083-096.md \
        harness/bench_tapenade_set01_lh083_096.f90 \
        scripts/bench_tapenade_set01_lh083_096.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
