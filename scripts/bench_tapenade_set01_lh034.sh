#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh034 and its bounded port.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01/lh034"
result="$root/results/tapenade_set01_lh034_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
normal_free=(-std=f2018 -pedantic-errors -Wall -Wextra -ffree-line-length-none -fno-lto)
upstream_dir="$tapenade_repo/nonRegressions/set01/lh034"

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_d.f program_d.msg; do
    test -s "$upstream_dir/$source"
done
test ! -e "$upstream_dir/program_b.f"
test ! -e "$upstream_dir/program_dv.f"
test -s "$case_dir/port.f90"
test -s "$case_dir/hand.f90"
test -s "$root/harness/bench_tapenade_set01_lh034.f90"

out=$(mktemp -d /var/tmp/tapenade-set01-lh034.XXXXXX)
clean_fortad_repo=
cleanup() {
    rm -rf "$out"
    if test -n "$clean_fortad_repo"; then
        rm -rf "$clean_fortad_repo"
    fi
}
trap cleanup EXIT

fortad_original_commit=$(git -C "$fortad_repo" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_repo" status --porcelain --untracked-files=no)
if test "$fortad_original_commit" != "$required_fortad_commit" || \
        test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_repo")/fortad-lh034-clean.XXXXXX")
    git clone --shared --quiet "$fortad_repo" "$clean_fortad_repo"
    git -C "$clean_fortad_repo" checkout --detach --quiet "$required_fortad_commit"
    fortad_repo="$clean_fortad_repo"
fi
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"

mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse"

fortad_bin=${FORTAD_BIN:-"$fortad_repo/build/fo/bin/fortad"}
if test ! -x "$fortad_bin"; then
    command -v fo >/dev/null
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
fi
test -x "$fortad_bin"
tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
test -x "$tapenade"

compile_capture() {
    local source=$1 object=$2 label=$3 profile=$4
    local -a flags
    if test "$profile" = fixed; then
        flags=("${strict_fixed[@]}")
    else
        flags=("${normal_free[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

run_expected_failure() {
    local label=$1 diagnostic=$2
    shift 2
    set +e
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    test "$status" -ne 0
    grep -Fqx "$diagnostic" "$out/$label.stderr"
}

upstream_start=$(date +%s.%N)
compile_capture "$upstream_dir/program.f" "$out/upstream-program.o" \
    upstream-program fixed
compile_capture "$upstream_dir/program_d.f" "$out/upstream-program_d.o" \
    upstream-program_d fixed
test "$(cat "$out/upstream-program.status")" = 0
test "$(cat "$out/upstream-program_d.status")" = 0
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

tap_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -root invert -o lh034 \
    "$upstream_dir/program.f") >"$out/tapenade-parser.stdout" \
    2>"$out/tapenade-parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -root invert -o lh034 \
    "$upstream_dir/program.f") >"$out/tapenade-forward.stdout" \
    2>"$out/tapenade-forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -root invert -o lh034 \
    "$upstream_dir/program.f") >"$out/tapenade-reverse.stdout" \
    2>"$out/tapenade-reverse.stderr"
tap_stop=$(date +%s.%N)
tap_seconds=$(awk -v a="$tap_start" -v b="$tap_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_capture "$out/tapenade/parser/lh034_p.f" \
    "$out/tapenade-parser.o" tapenade-parser fixed
compile_capture "$out/tapenade/forward/lh034_d.f" \
    "$out/tapenade-forward.o" tapenade-forward fixed
compile_capture "$out/tapenade/reverse/lh034_b.f" \
    "$out/tapenade-reverse.o" tapenade-reverse fixed
test "$(cat "$out/tapenade-parser.status")" = 0
test "$(cat "$out/tapenade-forward.status")" = 0
test "$(cat "$out/tapenade-reverse.status")" = 1
grep -Fq 'INTEGER*4' "$out/tapenade-reverse.stderr"
grep -Fq 'branch' "$out/tapenade-reverse.stderr"

exact_diagnostic='fortad: unsupported statement at line 23'
exact_start=$(date +%s.%N)
run_expected_failure exact-forward "$exact_diagnostic" "$fortad_bin" \
    --mode forward --indep a0,b0 --dep invert --proc invert \
    --name lh034_exact_forward --module lh034_exact_forward_mod \
    --output "$out/lh034_exact_forward.f90" "$upstream_dir/program.f"
run_expected_failure exact-reverse "$exact_diagnostic" "$fortad_bin" \
    --mode reverse --indep a0,b0 --dep invert --proc invert \
    --name lh034_exact_reverse --module lh034_exact_reverse_mod \
    --output "$out/lh034_exact_reverse.f90" "$upstream_dir/program.f"
exact_stop=$(date +%s.%N)
exact_seconds=$(awk -v a="$exact_start" -v b="$exact_stop" \
    'BEGIN {printf "%.6f", b-a}')
test ! -e "$out/lh034_exact_forward.f90"
test ! -e "$out/lh034_exact_reverse.f90"

port_start=$(date +%s.%N)
"$fortad_bin" --mode forward --indep a0,b0 --dep root \
    --proc set01_lh034 --name lh034_forward --module lh034_forward_mod \
    --output "$out/lh034_forward.f90" "$case_dir/port.f90" \
    >"$out/fortad-port-forward.stdout" 2>"$out/fortad-port-forward.stderr"
printf '%s\n' "$?" >"$out/fortad-port-forward.status"
test "$(cat "$out/fortad-port-forward.status")" = 0
port_reverse_diagnostic='fortad: reverse mode: a branch inside a loop needs control-flow reversal, which is the next milestone'
run_expected_failure port-reverse "$port_reverse_diagnostic" "$fortad_bin" \
    --mode reverse --indep a0,b0 --dep root --proc set01_lh034 \
    --name lh034_reverse --module lh034_reverse_mod \
    --output "$out/lh034_reverse.f90" "$case_dir/port.f90"
port_stop=$(date +%s.%N)
port_seconds=$(awk -v a="$port_start" -v b="$port_stop" \
    'BEGIN {printf "%.6f", b-a}')
test -s "$out/lh034_forward.f90"
test ! -e "$out/lh034_reverse.f90"

compile_start=$(date +%s.%N)
compile_capture "$case_dir/port.f90" "$out/port.o" port normal
compile_capture "$case_dir/hand.f90" "$out/hand.o" hand normal
compile_capture "$out/lh034_forward.f90" "$out/fortad-forward.o" \
    fortad-forward normal
compile_capture "$root/harness/bench_tapenade_set01_lh034.f90" \
    "$out/harness.o" harness normal
for label in port hand fortad-forward harness; do
    test "$(cat "$out/$label.status")" = 0
done
"$fc" "${normal_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/port.o" "$out/hand.o" "$out/fortad-forward.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
run_status=$?
set -e
test "$run_status" = 0
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
mkdir -p "$root/results"
{
    printf 'case: Tapenade nonRegressions set01 lh034\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'normal_free_flags: %s\n' "${normal_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_binary: %s\n' "$fortad_bin"
    printf 'fortad_binary_sha256: %s\n' "$(sha256sum "$fortad_bin" | awk '{print $1}')"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'tapenade_fresh_generation_seconds: %s\n' "$tap_seconds"
    printf 'fortad_exact_refusal_seconds: %s\n' "$exact_seconds"
    printf 'fortad_bounded_port_seconds: %s\n' "$port_seconds"
    printf 'bounded_port_compile_link_seconds: %s\n' "$compile_seconds"
    printf 'upstream_exact_source_compile_statuses:\n'
    printf 'program.status %s\n' "$(cat "$out/upstream-program.status")"
    printf 'program_d.status %s\n' "$(cat "$out/upstream-program_d.status")"
    printf 'program_d.msg.present 1\n'
    printf 'program_b.f.present 0\n'
    printf 'program_dv.f.present 0\n'
    printf 'tapenade_result: fresh parser and tangent compile strictly; '
    printf '%s\n' 'fresh reverse generation succeeds but strict compilation refuses INTEGER*4 branch'
    printf 'tapenade_generated_compile_statuses:\n'
    printf 'parser.status %s\n' "$(cat "$out/tapenade-parser.status")"
    printf 'forward.status %s\n' "$(cat "$out/tapenade-forward.status")"
    printf 'reverse.status %s\n' "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_reverse_diagnostic: INTEGER*4 branch; branch has no IMPLICIT NONE declaration\n'
    printf 'fortad_exact_forward_status: %s\n' "$(cat "$out/exact-forward.status")"
    printf 'fortad_exact_reverse_status: %s\n' "$(cat "$out/exact-reverse.status")"
    printf 'fortad_exact_diagnostic: %s\n' "$exact_diagnostic"
    printf 'fortad_exact_result: expected-refusal; unresolved external callback semantics not claimed\n'
    printf 'fortad_port_forward_status: %s\n' "$(cat "$out/fortad-port-forward.status")"
    printf 'fortad_port_reverse_status: %s\n' "$(cat "$out/port-reverse.status")"
    printf 'fortad_port_reverse_diagnostic: %s\n' "$port_reverse_diagnostic"
    printf 'fortad_port_result: bounded quadratic callback forward transform compiles; reverse remains refused\n'
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity on fixed branch path\n'
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        nonRegressions/set01/lh034/program.f \
        nonRegressions/set01/lh034/program_d.f \
        nonRegressions/set01/lh034/program_d.msg)
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh034/manifest.toml \
        cases/tapenade-set01/lh034/notes.md \
        cases/tapenade-set01/lh034/port.f90 \
        cases/tapenade-set01/lh034/hand.f90 \
        harness/bench_tapenade_set01_lh034.f90 \
        scripts/bench_tapenade_set01_lh034.sh \
        scripts/test_tapenade_set01_lh034.py)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
