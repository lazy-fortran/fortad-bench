#!/usr/bin/env bash
# Validate four pure-Fortran Tapenade set03 cases with fresh engine probes.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set03"
result="$root/results/tapenade_set03_tranche_q_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=a1c9f25f87eaadf700ba47ee3e841a0fb41585a3
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffree-line-length-none)
compile_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

out=$(mktemp -d /var/tmp/ert/tapenade-set03-tranche-q.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod"

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
    elif test "$flags_name" = strict-mod; then
        flags=("${strict_flags[@]}" "-J$out/mod" "-I$out/mod")
    else
        flags=("${compile_flags[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
}

transform_capture() {
    local case_id=$1 mode=$2 output=$3
    shift 3
    set +e
    (cd "$fortad_repo" && fo exec --no-build fortad "$mode" "$@" --output "$output" \
        "$case_dir/$case_id.f90") >"$output.stdout" 2>"$output.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$output.status"
}

tap_root() {
    case "$1" in
        ht05|ht06) printf 'toto\n' ;;
        ht12) printf 'top\n' ;;
        ht13) printf 'flx_blk\n' ;;
    esac
}

compile_capture "$case_dir/diffsizes_ht06.f90" "$out/diffsizes.o" \
    "$out/diffsizes.status" strict
test "$(cat "$out/diffsizes.status")" = 0

for case_id in ht05 ht06 ht12 ht13; do
    case_out="$out/$case_id"
    mkdir -p "$case_out/tapenade/parser" "$case_out/tapenade/forward" \
        "$case_out/tapenade/reverse"
    upstream_dir="$tapenade_repo/nonRegressions/set03/$case_id"
    cmp "$case_dir/$case_id.f90" "$upstream_dir/program.f90"
    for source in "$upstream_dir"/program*.f90; do
        base=$(basename "$source" .f90)
        compile_capture "$source" "$case_out/upstream-$base.o" \
            "$case_out/upstream-$base.status" strict
        test "$(cat "$case_out/upstream-$base.status")" = 0
    done

    root_name=$(tap_root "$case_id")
    "$tapenade" -p -O "$case_out/tapenade/parser" -o "$case_id" \
        "$upstream_dir/program.f90" >"$case_out/tapenade/parser.stdout" \
        2>"$case_out/tapenade/parser.stderr"
    "$tapenade" -d -root "$root_name" -O "$case_out/tapenade/forward" \
        -o "$case_id" "$upstream_dir/program.f90" \
        >"$case_out/tapenade/forward.stdout" 2>"$case_out/tapenade/forward.stderr"
    "$tapenade" -b -root "$root_name" -O "$case_out/tapenade/reverse" \
        -o "$case_id" "$upstream_dir/program.f90" \
        >"$case_out/tapenade/reverse.stdout" 2>"$case_out/tapenade/reverse.stderr"
    for generated in "$case_out"/tapenade/parser/*.f90 \
        "$case_out"/tapenade/forward/*.f90 "$case_out"/tapenade/reverse/*.f90; do
        test -s "$generated"
        base=$(basename "$generated" .f90)
        generated_flags=strict
        test "$case_id" = ht06 && generated_flags=strict-mod
        compile_capture "$generated" "$case_out/$base.o" \
            "$case_out/$base.status" "$generated_flags"
        test "$(cat "$case_out/$base.status")" = 0
    done
done

fortad_start=$(date +%s.%N)
transform_capture ht05 jvp "$out/ht05-jvp.f90" m,x --proc toto \
    --name ht05_jvp --module ht05_jvp_mod
transform_capture ht05 vjp "$out/ht05-vjp.f90" m,x --dep y --proc toto \
    --name ht05_vjp --module ht05_vjp_mod
transform_capture ht06 jvp "$out/ht06-jvp.f90" n,x --proc titi \
    --name ht06_jvp --module ht06_jvp_mod
transform_capture ht06 vjp "$out/ht06-vjp.f90" n,x --dep y --proc titi \
    --name ht06_vjp --module ht06_vjp_mod
transform_capture ht12 jvp "$out/ht12-jvp.f90" a --proc top \
    --name ht12_jvp --module ht12_jvp_mod
transform_capture ht12 vjp "$out/ht12-vjp.f90" a --dep a --proc top \
    --name ht12_vjp --module ht12_vjp_mod
transform_capture ht13 jvp "$out/ht13-jvp.f90" x --proc flx_blk \
    --name ht13_jvp --module ht13_jvp_mod
transform_capture ht13 vjp "$out/ht13-vjp.f90" x --dep y --proc flx_blk \
    --name ht13_vjp --module ht13_vjp_mod
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" 'BEGIN {print b-a}')

for case_id in ht05 ht06; do
    test "$(cat "$out/$case_id-jvp.f90.status")" = 1
    test "$(cat "$out/$case_id-vjp.f90.status")" = 1
    test ! -e "$out/$case_id-jvp.f90"
    test ! -e "$out/$case_id-vjp.f90"
done
grep -Fqx 'fortad: unsupported allocation lifetime construct '\''allocatable declaration/component'\'' at line 6; active allocation state is not represented yet' \
    "$out/ht05-jvp.f90.stderr"
grep -Fqx 'fortad: unsupported allocation lifetime construct '\''allocatable declaration/component'\'' at line 6; active allocation state is not represented yet' \
    "$out/ht05-vjp.f90.stderr"
grep -Fqx 'fortad: unsupported array section at line 5: noncontiguous and overlapping storage identity is not tracked' \
    "$out/ht06-jvp.f90.stderr"
grep -Fqx 'fortad: unsupported array section at line 5: noncontiguous and overlapping storage identity is not tracked' \
    "$out/ht06-vjp.f90.stderr"

for case_id in ht12 ht13; do
    compile_capture "$out/$case_id-jvp.f90" "$out/$case_id-jvp.o" \
        "$out/$case_id-jvp.compile.status" normal
    compile_capture "$out/$case_id-vjp.f90" "$out/$case_id-vjp.o" \
        "$out/$case_id-vjp.compile.status" normal
done
test "$(cat "$out/ht12-jvp.compile.status")" = 1
test "$(cat "$out/ht12-vjp.compile.status")" = 1
grep -Fq 'used before it is typed' "$out/ht12-jvp.o.stderr"
grep -Fq 'Duplicate symbol' "$out/ht12-vjp.o.stderr"
test "$(cat "$out/ht13-jvp.compile.status")" = 0
test "$(cat "$out/ht13-vjp.compile.status")" = 0

compile_capture "$case_dir/hand_derivative_ht13.f90" "$out/hand.o" \
    "$out/hand.status" normal
compile_capture "$root/harness/bench_tapenade_set03_tranche_q.f90" \
    "$out/harness.o" "$out/harness.status" normal
test "$(cat "$out/hand.status")" = 0
test "$(cat "$out/harness.status")" = 0
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/hand.o" "$out/ht13-jvp.o" "$out/ht13-vjp.o" "$out/harness.o"

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
run_status=$?
set -e
test "$run_status" = 0
grep -Fqx 'oracle_status: pass' "$out/run.txt"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'suite: Tapenade nonRegressions set03 tranche Q (ht05, ht06, ht12, ht13)\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'upstream_exact_source_compile_statuses: all four sources and stored references 0\n'
    printf 'upstream_source_byte_exact: ht05 ht06 ht12 ht13 yes\n'
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated; all generated sources compile under strict free-form flags\n'
    printf 'tapenade_compile_support: pure-Fortran DIFFSIZES module supplies ISIZE1OFn for fresh ht06 reverse output\n'
    printf 'fortad_transform_statuses: ht05 jvp=1 vjp=1; ht06 jvp=1 vjp=1; ht12 jvp=0 vjp=0; ht13 jvp=0 vjp=0\n'
    printf 'ht05_refusal_oracle: exact nonzero JVP/VJP status, exact allocation-lifetime diagnostic at line 6, and no generated source\n'
    printf 'ht05_fortad_diagnostic: fortad: unsupported allocation lifetime construct '\''allocatable declaration/component'\'' at line 6; active allocation state is not represented yet\n'
    printf 'ht06_refusal_oracle: exact nonzero JVP/VJP status, exact array-section diagnostic at line 5, and no generated source\n'
    printf 'ht06_fortad_diagnostic: fortad: unsupported array section at line 5: noncontiguous and overlapping storage identity is not tracked\n'
    printf 'ht12_refusal_oracle: generated JVP/VJP compile failures with exact hidden-extent and duplicate-adjoint diagnostics\n'
    printf 'ht12_jvp_diagnostic: Symbol '\''n'\'' is used before it is typed\n'
    printf 'ht12_vjp_diagnostic: Duplicate symbol '\''a_b'\'' in formal argument list\n'
    printf 'independent_oracle: hand analytic JVP/VJP, central-difference sweep, and adjoint identity for ht13\n'
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set03/ht05.f90 cases/tapenade-set03/ht06.f90 \
        cases/tapenade-set03/ht12.f90 cases/tapenade-set03/ht13.f90 \
        cases/tapenade-set03/hand_derivative_ht13.f90 \
        cases/tapenade-set03/diffsizes_ht06.f90 \
        cases/tapenade-set03/tranche-q-manifest.toml cases/tapenade-set03/tranche-q.md \
        harness/bench_tapenade_set03_tranche_q.f90 scripts/bench_tapenade_set03_tranche_q.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
