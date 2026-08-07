#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh024 and its bounded port.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh024_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
normal_flags=(-std=f2018 -pedantic-errors -Wall -Wextra -ffree-line-length-none -fno-lto)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v /usr/bin/time >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

fortad_bin=${FORTAD_BIN:-"$fortad_repo/build/fo/bin/fortad"}
if test ! -x "$fortad_bin"; then
    command -v fo >/dev/null
    (cd "$fortad_repo" && fo build) >"/tmp/fortad-lh024-build.log" 2>&1 < /dev/null
fi
test -x "$fortad_bin"
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

out=$(mktemp -d /var/tmp/ert/tapenade-set01-lh024.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/include" "$out/mod" "$out/tapenade/parser" \
    "$out/tapenade/forward" "$out/tapenade/reverse"
cp "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/include/DIFFSIZES.inc"
upstream_dir="$tapenade_repo/nonRegressions/set01/lh024"
source="$upstream_dir/program.f"

compile_capture() {
    local input=$1 object=$2 label=$3 profile=$4
    local -a flags
    if test "$profile" = strict; then
        flags=("${strict_flags[@]}")
    elif test "$profile" = strict_include; then
        flags=("${strict_flags[@]}" "-I$out/include")
    else
        flags=("${normal_flags[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$input" -o "$object" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

for stored in program program_d program_b; do
    compile_capture "$upstream_dir/$stored.f" "$out/upstream-$stored.o" \
        "upstream-$stored" strict
    test "$(cat "$out/upstream-$stored.status")" = 0
done
compile_capture "$upstream_dir/program_dv.f" "$out/upstream-program_dv.o" \
    upstream-program_dv strict_include
test "$(cat "$out/upstream-program_dv.status")" = 0

tapenade_start=$(date +%s.%N)
"$tapenade" -p -O "$out/tapenade/parser" -o lh024 "$source" \
    >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
"$tapenade" -d -root test -O "$out/tapenade/forward" -o lh024 "$source" \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
"$tapenade" -b -root test -O "$out/tapenade/reverse" -o lh024 "$source" \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_capture "$out/tapenade/parser/lh024_p.f" \
    "$out/tapenade-parser.o" tapenade-parser strict
test "$(cat "$out/tapenade-parser.status")" = 0
compile_capture "$out/tapenade/forward/lh024_d.f" \
    "$out/tapenade-forward.o" tapenade-forward strict
test "$(cat "$out/tapenade-forward.status")" = 0
compile_capture "$out/tapenade/reverse/lh024_b.f" \
    "$out/tapenade-reverse.o" tapenade-reverse strict
test "$(cat "$out/tapenade-reverse.status")" = 0

run_fortad_expected_refusal() {
    local label=$1 diagnostic=$2
    shift 2
    set +e
    "$fortad_bin" "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    test "$status" -ne 0
    grep -Fqx "$diagnostic" "$out/$label.stderr"
}

exact_diagnostic='fortad: inlining sub1 needs plain variables as arguments, because it may write to them'
fortad_exact_start=$(date +%s.%N)
run_fortad_expected_refusal exact-forward "$exact_diagnostic" \
    --mode forward --indep x,y --proc test --name lh024_exact_jvp \
    --module lh024_exact_forward --output "$out/lh024_exact_forward.f90" \
    "$source"
run_fortad_expected_refusal exact-reverse "$exact_diagnostic" \
    --mode reverse --indep x,y --dep x --proc test --name lh024_exact_vjp \
    --module lh024_exact_reverse --output "$out/lh024_exact_reverse.f90" \
    "$source"
fortad_exact_stop=$(date +%s.%N)
fortad_exact_seconds=$(awk -v a="$fortad_exact_start" -v b="$fortad_exact_stop" \
    'BEGIN {printf "%.6f", b-a}')
test ! -e "$out/lh024_exact_forward.f90"
test ! -e "$out/lh024_exact_reverse.f90"

fortad_port_start=$(date +%s.%N)
"$fortad_bin" --mode forward --indep x,y --proc set01_lh024 \
    --name lh024_jvp --module lh024_forward_ad \
    --output "$out/lh024_forward.f90" "$case_dir/lh024.f90" \
    >"$out/port-forward.stdout" 2>"$out/port-forward.stderr"
printf '%s\n' "$?" >"$out/port-forward.status"
test "$(cat "$out/port-forward.status")" = 0
port_reverse_diagnostic="fortad: reverse mode: 'x' is both read and written in the same loop; that needs per-iteration storage"
run_fortad_expected_refusal port-reverse "$port_reverse_diagnostic" \
    --mode reverse --indep x,y --dep x --proc set01_lh024 \
    --name lh024_vjp --module lh024_reverse_ad \
    --output "$out/lh024_reverse.f90" "$case_dir/lh024.f90"
fortad_port_stop=$(date +%s.%N)
fortad_port_seconds=$(awk -v a="$fortad_port_start" -v b="$fortad_port_stop" \
    'BEGIN {printf "%.6f", b-a}')
test -s "$out/lh024_forward.f90"
test ! -e "$out/lh024_reverse.f90"

compile_start=$(date +%s.%N)
compile_capture "$case_dir/lh024.f90" "$out/port-case.o" port-case normal
test "$(cat "$out/port-case.status")" = 0
compile_capture "$case_dir/hand_derivative_lh024.f90" "$out/hand.o" hand normal
test "$(cat "$out/hand.status")" = 0
compile_capture "$out/lh024_forward.f90" "$out/fortad-forward.o" fortad-forward normal
test "$(cat "$out/fortad-forward.status")" = 0
compile_capture "$root/harness/bench_tapenade_set01_lh024.f90" \
    "$out/harness.o" harness normal
test "$(cat "$out/harness.status")" = 0
"$fc" "${normal_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/port-case.o" "$out/hand.o" "$out/fortad-forward.o" "$out/harness.o" \
    >"$out/link.stdout" 2>"$out/link.stderr"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
mkdir -p "$root/results"
{
    printf 'case: Tapenade nonRegressions set01 lh024 exact-source refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'normal_compiler_flags: %s\n' "${normal_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_binary: %s\n' "$fortad_bin"
    printf 'fortad_binary_sha256: %s\n' "$(sha256sum "$fortad_bin" | awk '{print $1}')"
    printf 'tapenade_generation_seconds_total: %s\n' "$tapenade_seconds"
    printf 'fortad_exact_refusal_seconds_total: %s\n' "$fortad_exact_seconds"
    printf 'fortad_bounded_port_seconds_total: %s\n' "$fortad_port_seconds"
    printf 'bounded_port_compile_link_seconds: %s\n' "$compile_seconds"
    printf 'upstream_exact_source_compile_statuses:\n'
    for status in "$out"/upstream-*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'tapenade_result: fresh parser, tangent, and reverse files generated; '
    printf '%s\n' 'all generated sources compile under strict fixed-form flags'
    printf 'tapenade_generated_compile_statuses:\n'
    for status in "$out"/tapenade-*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'fortad_exact_forward_status: %s\n' "$(cat "$out/exact-forward.status")"
    printf 'fortad_exact_reverse_status: %s\n' "$(cat "$out/exact-reverse.status")"
    printf 'fortad_exact_diagnostic: %s\n' "$exact_diagnostic"
    printf 'fortad_exact_result: expected-refusal; no exact-source support claimed\n'
    printf 'fortad_port_forward_status: %s\n' "$(cat "$out/port-forward.status")"
    printf 'fortad_port_reverse_status: %s\n' "$(cat "$out/port-reverse.status")"
    printf 'fortad_port_reverse_diagnostic: %s\n' "$port_reverse_diagnostic"
    printf 'fortad_port_result: forward transform and strict compile pass; '
    printf '%s\n' 'reverse remains an expected per-iteration-storage refusal'
    printf 'independent_oracle: hand JVP/VJP, four-step central-difference sweep, '
    printf '%s\n' 'and JVP/VJP adjoint identity'
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        nonRegressions/set01/lh024/program.f \
        nonRegressions/set01/lh024/program_d.f \
        nonRegressions/set01/lh024/program_dv.f \
        nonRegressions/set01/lh024/program_b.f \
        nonRegressions/set01/lh024/program_d.msg \
        nonRegressions/set01/lh024/program_dv.msg \
        nonRegressions/set01/lh024/program_b.msg)
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh024.f90 \
        cases/tapenade-set01/hand_derivative_lh024.f90 \
        cases/tapenade-set01/lh024-manifest.toml \
        cases/tapenade-set01/lh024.md \
        harness/bench_tapenade_set01_lh024.f90 \
        scripts/bench_tapenade_set01_lh024.sh \
        scripts/test_tapenade_set01_lh024.py)
    printf 'classification: expected-refusal-exact-source-call-boundary\n'
    printf 'status: expected-refusal\n'
    printf 'refusal_reason: exact source is strict Fortran and Tapenade-clean, '
    printf '%s\n' 'but FortAD cannot inline the mutating sub1 actuals; the bounded port is numerical evidence only'
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
