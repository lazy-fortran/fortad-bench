#!/usr/bin/env bash
# Validate pure-Fortran Tapenade set05/v150, set05/v168, set06/v314, v379.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
result="$root/results/tapenade_set05_set06_tranche_b_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
if test -d "$root/upstream/tapenade"; then
    tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
else
    tapenade_repo=${TAPENADE_REPO:-"$root/../fortad-bench/upstream/tapenade"}
fi
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
test -x "$tapenade_repo/bin/tapenade"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

out=$(mktemp -d /var/tmp/ert/tapenade-set05-set06-tranche-b.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade"

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
tapenade="$tapenade_repo/bin/tapenade"

compile_capture() {
    local source=$1 object=$2 status_file=$3 kind=$4
    local -a flags
    if test "$kind" = strict; then
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

ids=(v150 v168 v314 v379)
sets=(set05 set05 set06 set06)
roots=(f test test1 subr)
for i in "${!ids[@]}"; do
    id=${ids[$i]}; set_name=${sets[$i]}; entry=${roots[$i]}
    upstream_dir="$tapenade_repo/nonRegressions/$set_name/$id"
    case_dir="$root/cases/tapenade-$set_name"
    mkdir -p "$out/tapenade/$id/parser" "$out/tapenade/$id/forward" "$out/tapenade/$id/reverse"
    for source in "$upstream_dir"/program*.f90; do
        base=$(basename "$source" .f90)
        compile_capture "$source" "$out/upstream-$id-$base.o" "$out/upstream-$id-$base.status" strict
        test "$(cat "$out/upstream-$id-$base.status")" = 0
    done
    for mode in p d b; do
        case "$mode" in p) kind=parser;; d) kind=forward;; b) kind=reverse;; esac
        "$tapenade" "-$mode" -root "$entry" -O "$out/tapenade/$id/$kind" \
            -o "${id}_${mode}" "$upstream_dir/program.f90" \
            >"$out/tapenade/$id/$kind.stdout" 2>"$out/tapenade/$id/$kind.stderr"
        generated=$(find "$out/tapenade/$id/$kind" -maxdepth 1 -name '*.f90' -print)
        test -n "$generated"
        while IFS= read -r source; do
            compile_capture "$source" "$source.o" "$source.status" strict
            test "$(cat "$source.status")" = 0
        done <<<"$generated"
    done
done

fortad_exec() { (cd "$fortad_repo" && fo exec --no-build fortad "$@"); }
fortad_start=$(date +%s.%N)
fortad_exec jvp t --dep f --proc set05_v150 --name v150_jvp --module v150_forward_ad \
    --output "$out/v150_forward.f90" "$root/cases/tapenade-set05/v150.f90" \
    >"$out/v150-fortad-forward.log" 2>&1
fortad_exec vjp t --dep f --proc set05_v150 --name v150_vjp --module v150_reverse_ad \
    --output "$out/v150_reverse.f90" "$root/cases/tapenade-set05/v150.f90" \
    >"$out/v150-fortad-reverse.log" 2>&1
fortad_exec jvp x --dep y --proc set05_v168 --name v168_jvp --module v168_forward_ad \
    --output "$out/v168_forward.f90" "$root/cases/tapenade-set05/v168.f90" \
    >"$out/v168-fortad-forward.log" 2>&1
fortad_exec vjp x --dep y --proc set05_v168 --name v168_vjp --module v168_reverse_ad \
    --output "$out/v168_reverse.f90" "$root/cases/tapenade-set05/v168.f90" \
    >"$out/v168-fortad-reverse.log" 2>&1
fortad_exec jvp y,z --dep x --proc set06_v314 --name v314_jvp --module v314_forward_ad \
    --output "$out/v314_forward.f90" "$root/cases/tapenade-set06/v314.f90" \
    >"$out/v314-fortad-forward.log" 2>&1
fortad_exec vjp y,z --dep x --proc set06_v314 --name v314_vjp --module v314_reverse_ad \
    --output "$out/v314_reverse.f90" "$root/cases/tapenade-set06/v314.f90" \
    >"$out/v314-fortad-reverse.log" 2>&1
fortad_exec jvp x --dep f --proc set06_v379 --name v379_jvp --module v379_forward_ad \
    --output "$out/v379_forward.f90" "$root/cases/tapenade-set06/v379.f90" \
    >"$out/v379-fortad-forward.log" 2>&1
fortad_exec vjp x --dep f --proc set06_v379 --name v379_vjp --module v379_reverse_ad \
    --output "$out/v379_reverse.f90" "$root/cases/tapenade-set06/v379.f90" \
    >"$out/v379-fortad-reverse.log" 2>&1
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" 'BEGIN {print b-a}')

compile_start=$(date +%s.%N)
for source in \
    "$root/cases/tapenade-set05/v150.f90" "$root/cases/tapenade-set05/hand_derivative_v150.f90" \
    "$root/cases/tapenade-set05/v168.f90" "$root/cases/tapenade-set05/hand_derivative_v168.f90" \
    "$root/cases/tapenade-set06/v314.f90" "$root/cases/tapenade-set06/hand_derivative_v314.f90" \
    "$root/cases/tapenade-set06/v379.f90" "$root/cases/tapenade-set06/hand_derivative_v379.f90" \
    "$out"/v*_forward.f90 "$out"/v*_reverse.f90; do
    base=$(basename "$source" .f90)
    compile_capture "$source" "$out/$base.o" "$out/$base.status" normal
    test "$(cat "$out/$base.status")" = 0
done
compile_capture "$root/harness/bench_tapenade_set05_set06_tranche_b.f90" \
    "$out/harness.o" "$out/harness.status" normal
test "$(cat "$out/harness.status")" = 0
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out"/v150.o "$out"/hand_derivative_v150.o "$out"/v150_forward.o "$out"/v150_reverse.o \
    "$out"/v168.o "$out"/hand_derivative_v168.o "$out"/v168_forward.o "$out"/v168_reverse.o \
    "$out"/v314.o "$out"/hand_derivative_v314.o "$out"/v314_forward.o "$out"/v314_reverse.o \
    "$out"/v379.o "$out"/hand_derivative_v379.o "$out"/v379_forward.o "$out"/v379_reverse.o \
    "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" 'BEGIN {print b-a}')

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
run_status=$?
set -e
test "$run_status" -eq 0
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'suite: Tapenade nonRegressions set05/v150 set05/v168 set06/v314 set06/v379\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated; all generated sources compile under strict free-form flags\n'
    printf 'upstream_exact_source_compile_statuses:\n'
    for status in "$out"/upstream-*.status; do printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"; done
    printf 'tapenade_generated_compile_statuses:\n'
    find "$out/tapenade" -name '*.status' -print | sort | while read -r status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'fortad_transform_compile_statuses:\n'
    for status in "$out"/v*_forward.status "$out"/v*_reverse.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'independent_oracle: hand JVP/VJP, three-point central-difference sweep, and adjoint identity for every case\n'
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set05/v150.f90 cases/tapenade-set05/hand_derivative_v150.f90 \
        cases/tapenade-set05/v168.f90 cases/tapenade-set05/hand_derivative_v168.f90 \
        cases/tapenade-set05/tranche-b-v150-v168-manifest.toml cases/tapenade-set05/tranche-b-v150-v168.md \
        cases/tapenade-set06/v314.f90 cases/tapenade-set06/hand_derivative_v314.f90 \
        cases/tapenade-set06/v379.f90 cases/tapenade-set06/hand_derivative_v379.f90 \
        cases/tapenade-set06/tranche-b-v314-v379-manifest.toml cases/tapenade-set06/tranche-b-v314-v379.md \
        harness/bench_tapenade_set05_set06_tranche_b.f90 scripts/bench_tapenade_set05_set06_tranche_b.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
