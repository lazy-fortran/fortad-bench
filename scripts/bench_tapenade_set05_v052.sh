#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set05/v052 with fresh engine probes.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set05"
result="$root/results/tapenade_set05_v052_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffree-line-length-none)
compile_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

out=$(mktemp -d /var/tmp/ert/tapenade-set05-v052.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse"

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
    "$fc" "${flags[@]}" -c "$source" -o "$object" >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
}

upstream_dir="$tapenade_repo/nonRegressions/set05/v052"
for source in "$upstream_dir/program.f90" "$upstream_dir/program_p.f90" "$upstream_dir/program_d.f90"; do
    base=$(basename "$source" .f90)
    compile_capture "$source" "$out/upstream-$base.o" "$out/upstream-$base.status" strict
    test "$(cat "$out/upstream-$base.status")" = 0
done

tapenade_start=$(date +%s.%N)
"$tapenade" -p -O "$out/tapenade/parser" -o v052_p "$upstream_dir/program.f90" \
    >"$out/tapenade/parser.stdout" 2>"$out/tapenade/parser.stderr"
"$tapenade" -d -root test -O "$out/tapenade/forward" -o v052_d "$upstream_dir/program.f90" \
    >"$out/tapenade/forward.stdout" 2>"$out/tapenade/forward.stderr"
"$tapenade" -b -root test -O "$out/tapenade/reverse" -o v052_b "$upstream_dir/program.f90" \
    >"$out/tapenade/reverse.stdout" 2>"$out/tapenade/reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" 'BEGIN {print b-a}')

for generated in "$out/tapenade/parser/v052_p_p.f90" \
    "$out/tapenade/forward/v052_d_d.f90" "$out/tapenade/reverse/v052_b_b.f90"; do
    test -s "$generated"
    compile_capture "$generated" "$generated.o" "$generated.status" strict
    test "$(cat "$generated.status")" = 0
done

fortad_exec() { (cd "$fortad_repo" && fo exec --no-build fortad "$@"); }
fortad_start=$(date +%s.%N)
fortad_exec jvp x --proc set05_v052 --name set05_v052_jvp \
    --module tapenade_set05_v052_forward_ad --output "$out/forward.f90" \
    "$case_dir/v052.f90" >"$out/fortad-forward.stdout" 2>"$out/fortad-forward.stderr"
fortad_exec vjp x --dep y --proc set05_v052 --name set05_v052_vjp \
    --module tapenade_set05_v052_reverse_ad --output "$out/reverse.f90" \
    "$case_dir/v052.f90" >"$out/fortad-reverse.stdout" 2>"$out/fortad-reverse.stderr"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" 'BEGIN {print b-a}')

compile_start=$(date +%s.%N)
for source in "$case_dir/v052.f90" "$case_dir/hand_derivative_v052.f90" \
    "$out/forward.f90" "$out/reverse.f90"; do
    base=$(basename "$source" .f90)
    compile_capture "$source" "$out/$base.o" "$out/$base.status" normal
    test "$(cat "$out/$base.status")" = 0
done
compile_capture "$root/harness/bench_tapenade_set05_v052.f90" \
    "$out/harness.o" "$out/harness.status" normal
test "$(cat "$out/harness.status")" = 0
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/v052.o" "$out/hand_derivative_v052.o" "$out/forward.o" \
    "$out/reverse.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" 'BEGIN {print b-a}')

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
run_status=$?
set -e
if test "$run_status" -ne 0 || ! grep -Fqx 'oracle_status: pass' "$out/run.txt"; then
    cat "$out/run.txt" >&2
    cat "$out/run.stderr" >&2
    exit 1
fi

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'suite: Tapenade nonRegressions set05 v052\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'tapenade_transform_seconds_total: %s\n' "$tapenade_seconds"
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'generated_compile_seconds_total: %s\n' "$compile_seconds"
    printf 'upstream_exact_source_compile_statuses:\n'
    for status in "$out"/upstream-*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated; all generated sources compile under strict flags\n'
    printf 'tapenade_generated_compile_statuses:\n'
    find "$out/tapenade" -name '*.status' -print | sort | while read -r status; do
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
        cases/tapenade-set05/v052.f90 \
        cases/tapenade-set05/hand_derivative_v052.f90 \
        cases/tapenade-set05/tranche-v052-manifest.toml \
        cases/tapenade-set05/tranche-v052.md \
        harness/bench_tapenade_set05_v052.f90 \
        scripts/bench_tapenade_set05_v052.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
