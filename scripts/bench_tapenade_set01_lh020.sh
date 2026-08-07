#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh020 with fresh engine probes.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh020_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
compile_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh020.XXXXXX")
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse"

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
    if test "$status" -ne 0; then
        cat "$object.stdout" "$object.stderr" >&2
        return "$status"
    fi
}

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" \
        2>&1 < /dev/null
fi
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

upstream_dir="$tapenade_repo/nonRegressions/set01/lh020"
for source in "$upstream_dir/program.f" "$upstream_dir/program_d.f" \
    "$upstream_dir/program_b.f"; do
    base=$(basename "$source" .f)
    compile_capture "$source" "$out/upstream-$base.o" \
        "$out/upstream-$base.status" strict
done

tapenade_start=$(date +%s.%N)
"$tapenade" -p -O "$out/tapenade/parser" -o lh020 \
    "$upstream_dir/program.f" >"$out/tapenade/parser.stdout" \
    2>"$out/tapenade/parser.stderr"
"$tapenade" -d -root top -O "$out/tapenade/forward" -o lh020 \
    "$upstream_dir/program.f" >"$out/tapenade/forward.stdout" \
    2>"$out/tapenade/forward.stderr"
"$tapenade" -b -root top -O "$out/tapenade/reverse" -o lh020 \
    "$upstream_dir/program.f" >"$out/tapenade/reverse.stdout" \
    2>"$out/tapenade/reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

for generated in "$out/tapenade/parser/lh020_p.f" \
    "$out/tapenade/forward/lh020_d.f" "$out/tapenade/reverse/lh020_b.f"; do
    test -s "$generated"
    base=$(basename "$generated")
    compile_capture "$generated" "$out/tapenade-$base.o" \
        "$out/tapenade-$base.status" strict
done

fortad_exec() { (cd "$fortad_repo" && fo exec --no-build fortad "$@"); }
fortad_start=$(date +%s.%N)
fortad_exec jvp x,y --dep x1_out --proc set01_lh020 --name lh020_jvp \
    --module lh020_forward_ad --output "$out/lh020_forward.f90" \
    "$case_dir/lh020.f90" >"$out/lh020-forward.stdout" \
    2>"$out/lh020-forward.stderr"
fortad_exec vjp x,y --dep x1_out --proc set01_lh020 --name lh020_vjp \
    --module lh020_reverse_ad --output "$out/lh020_reverse.f90" \
    "$case_dir/lh020.f90" >"$out/lh020-reverse.stdout" \
    2>"$out/lh020-reverse.stderr"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
for source in "$case_dir/lh020.f90" \
    "$case_dir/hand_derivatives_lh020.f90" "$out/lh020_forward.f90" \
    "$out/lh020_reverse.f90"; do
    base=$(basename "$source" .f90)
    compile_capture "$source" "$out/$base.o" "$out/$base.status" normal
done
compile_capture "$root/harness/bench_tapenade_set01_lh020.f90" \
    "$out/harness.o" "$out/harness.status" normal
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh020.o" "$out/hand_derivatives_lh020.o" \
    "$out/lh020_forward.o" "$out/lh020_reverse.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
run_status=$?
set -e
if test "$run_status" -ne 0 || ! grep -Fqx 'oracle_status: pass' "$out/run.txt"; then
    cat "$out/run.txt" "$out/run.stderr" >&2
    exit 1
fi

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
fortad_status=$(git -C "$fortad_repo" status --short --untracked-files=no)
{
    printf 'case: Tapenade nonRegressions set01 lh020\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'compile_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_worktree_status:\n%s\n' "$fortad_status"
    printf 'tapenade_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'fortad_transform_seconds: %s\n' "$fortad_seconds"
    printf 'generated_compile_seconds: %s\n' "$compile_seconds"
    printf 'upstream_exact_source_compile_statuses:\n'
    for status in "$out"/upstream-*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated; '
    printf '%s\n' 'all generated sources compile under strict fixed-form flags'
    printf 'tapenade_generated_compile_statuses:\n'
    for status in "$out"/tapenade-*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'fortad_oracle: bounded standard-conforming x1_out port; '
    printf '%s\n' 'forward and reverse outputs compile'
    printf 'fortad_transform_compile_statuses:\n'
    for status in "$out"/lh020*.status "$out"/hand_derivatives_lh020.status \
        "$out"/harness.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'independent_oracle: hand JVP/VJP, two positive n cases, '
    printf '%s\n' 'four-step central differences, branch status, and adjoint identity'
    printf 'runtime_status: %s\n' "$run_status"
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'exact_source_sha256:\n'
    sha256sum "$upstream_dir/program.f" "$upstream_dir/program_d.f" \
        "$upstream_dir/program_b.f"
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh020.f90 \
        cases/tapenade-set01/hand_derivatives_lh020.f90 \
        cases/tapenade-set01/lh020-manifest.toml \
        cases/tapenade-set01/lh020.md \
        harness/bench_tapenade_set01_lh020.f90 \
        scripts/bench_tapenade_set01_lh020.sh \
        scripts/test_tapenade_set01_lh020.py)
    printf 'fresh_tapenade_source_sha256:\n'
    sha256sum "$out/tapenade/parser/lh020_p.f" \
        "$out/tapenade/forward/lh020_d.f" "$out/tapenade/reverse/lh020_b.f"
    printf 'fresh_fortad_source_sha256:\n'
    sha256sum "$out/lh020_forward.f90" "$out/lh020_reverse.f90"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
