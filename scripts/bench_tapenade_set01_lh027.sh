#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh027 with exact-source, fresh-engine,
# and bounded-port evidence.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh027_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors \
              -Wall -Wextra -Wimplicit-interface)
compile_flags=(-std=f2018 -ffree-form -O2 -ffree-line-length-none -fno-lto \
               -pedantic-errors \
               -Wall -Wextra -Wimplicit-interface)
source="$tapenade_repo/nonRegressions/set01/lh027/program.f"

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test -x "$tapenade_repo/bin/tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -s "$source"

mkdir -p "$root/results"
out=$(mktemp -d /var/tmp/ert/tapenade-set01-lh027.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/exact" "$out/oracle"

compile_capture() {
    local input=$1 output=$2 status_file=$3 flags_name=$4
    local -a flags
    if test "$flags_name" = strict; then
        flags=("${strict_flags[@]}" "-I$upstream_dir" "-J$out/mod")
    else
        flags=("${compile_flags[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$input" -o "$output" \
        >"$output.stdout" 2>"$output.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
    printf '%s\n' "$status"
}

upstream_dir="$tapenade_repo/nonRegressions/set01/lh027"

printf '%s\n' '--- strict exact-source and stored-reference compilation ---'
upstream_program_status=$(compile_capture "$source" "$out/upstream-program.o" \
    "$out/upstream-program.status" strict)
upstream_d_status=$(compile_capture "$upstream_dir/program_d.f" \
    "$out/upstream-program_d.o" "$out/upstream-program_d.status" strict)
upstream_b_status=$(compile_capture "$upstream_dir/program_b.f" \
    "$out/upstream-program_b.o" "$out/upstream-program_b.status" strict)
upstream_dv_status=$(compile_capture "$upstream_dir/program_dv.f" \
    "$out/upstream-program_dv.o" "$out/upstream-program_dv.status" strict)
test "$upstream_program_status" = 0
test "$upstream_d_status" = 0
test "$upstream_b_status" = 1
test "$upstream_dv_status" = 1
grep -Fq 'Nonstandard type declaration INTEGER*4' \
    "$out/upstream-program_b.o.stderr"
grep -Fq 'Symbol' "$out/upstream-program_b.o.stderr"
grep -Fq 'Cannot open included file' "$out/upstream-program_dv.o.stderr"
for reference in program_b.msg program_d.msg program_dv.msg; do
    test -s "$upstream_dir/$reference"
done

printf '%s\n' '--- fresh pinned Tapenade parser, tangent, and reverse generation ---'
tapenade="$tapenade_repo/bin/tapenade"
tapenade_start=$(date +%s.%N)
"$tapenade" -p -O "$out/tapenade/parser" -o lh027 "$source" \
    >"$out/tapenade/parser.stdout" 2>"$out/tapenade/parser.stderr"
"$tapenade" -d -root s1 -O "$out/tapenade/forward" -o lh027 "$source" \
    >"$out/tapenade/forward.stdout" 2>"$out/tapenade/forward.stderr"
"$tapenade" -b -root s1 -O "$out/tapenade/reverse" -o lh027 "$source" \
    >"$out/tapenade/reverse.stdout" 2>"$out/tapenade/reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')
test -s "$out/tapenade/parser/lh027_p.f"
test -s "$out/tapenade/forward/lh027_d.f"
test -s "$out/tapenade/reverse/lh027_b.f"

printf '%s\n' '--- strict fresh Tapenade output compilation ---'
tapenade_parser_status=$(compile_capture "$out/tapenade/parser/lh027_p.f" \
    "$out/tapenade/parser.o" "$out/tapenade/parser.status" strict)
tapenade_forward_status=$(compile_capture "$out/tapenade/forward/lh027_d.f" \
    "$out/tapenade/forward.o" "$out/tapenade/forward.status" strict)
tapenade_reverse_status=$(compile_capture "$out/tapenade/reverse/lh027_b.f" \
    "$out/tapenade/reverse.o" "$out/tapenade/reverse.status" strict)
test "$tapenade_parser_status" = 0
test "$tapenade_forward_status" = 0
test "$tapenade_reverse_status" = 1
grep -Fq 'Nonstandard type declaration INTEGER*4' \
    "$out/tapenade/reverse.o.stderr"
grep -Fq 'Symbol' "$out/tapenade/reverse.o.stderr"

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

printf '%s\n' '--- FortAD exact-source boundary ---'
set +e
fortad_exec --mode forward --indep a,b --proc s1 --name lh027_exact_jvp \
    --module lh027_exact_forward_ad --output "$out/exact/forward.f90" "$source" \
    >"$out/exact/forward.stdout" 2>"$out/exact/forward.stderr"
fortad_exact_forward_status=$?
set -e
test "$fortad_exact_forward_status" = 0
test -s "$out/exact/forward.f90"
fortad_exact_forward_compile_status=$(compile_capture \
    "$out/exact/forward.f90" "$out/exact/forward.o" \
    "$out/exact/forward.status" normal)
test "$fortad_exact_forward_compile_status" = 0
grep -Fq 'uninitialized' "$out/exact/forward.o.stderr"

set +e
fortad_exec --mode reverse --indep a,b --dep a --proc s1 --name lh027_exact_vjp \
    --module lh027_exact_reverse_ad --output "$out/exact/reverse.f90" "$source" \
    >"$out/exact/reverse.stdout" 2>"$out/exact/reverse.stderr"
fortad_exact_reverse_status=$?
set -e
test "$fortad_exact_reverse_status" = 1
test ! -e "$out/exact/reverse.f90"
grep -Fqx "fortad: assignment to undeclared ')'" \
    <(grep -F 'fortad:' "$out/exact/reverse.stderr" | tail -1)

printf '%s\n' '--- FortAD bounded standard-conforming port ---'
fortad_start=$(date +%s.%N)
fortad_exec jvp a,b --proc set01_lh027 --name lh027_jvp \
    --module lh027_forward_ad --output "$out/oracle/forward.f90" \
    "$case_dir/lh027.f90" >"$out/oracle/forward.stdout" \
    2>"$out/oracle/forward.stderr"
fortad_port_forward_status=$?
fortad_exec vjp a,b --dep objective --no-primal --proc set01_lh027 --name lh027_vjp \
    --module lh027_reverse_ad --output "$out/oracle/reverse.f90" \
    "$case_dir/lh027.f90" >"$out/oracle/reverse.stdout" \
    2>"$out/oracle/reverse.stderr"
fortad_port_reverse_status=$?
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')
test "$fortad_port_forward_status" = 0
test "$fortad_port_reverse_status" = 0
test -s "$out/oracle/forward.f90"
test -s "$out/oracle/reverse.f90"

printf '%s\n' '--- strict port, generated-code, and harness compilation ---'
port_status=$(compile_capture "$case_dir/lh027.f90" "$out/oracle/port.o" \
    "$out/oracle/port.status" normal)
hand_status=$(compile_capture "$case_dir/hand_derivative_lh027.f90" \
    "$out/oracle/hand.o" "$out/oracle/hand.status" normal)
forward_status=$(compile_capture "$out/oracle/forward.f90" \
    "$out/oracle/forward.o" "$out/oracle/forward.status" normal)
reverse_status=$(compile_capture "$out/oracle/reverse.f90" \
    "$out/oracle/reverse.o" "$out/oracle/reverse.status" normal)
harness_status=$(compile_capture "$root/harness/bench_tapenade_set01_lh027.f90" \
    "$out/oracle/harness.o" "$out/oracle/harness.status" normal)
for status in "$port_status" "$hand_status" "$forward_status" \
              "$reverse_status" "$harness_status"; do
    test "$status" = 0
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -o "$out/oracle/bench" "$out/oracle/port.o" "$out/oracle/hand.o" \
    "$out/oracle/forward.o" "$out/oracle/reverse.o" "$out/oracle/harness.o"

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/oracle/runtime-metrics.txt" "$out/oracle/bench" \
    >"$out/oracle/run.txt" 2>"$out/oracle/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/oracle/run.txt"

fortad_tree_status=$(git -C "$fortad_repo" status --porcelain \
    --untracked-files=no | tr '\n' ';')
test -n "$fortad_tree_status" || fortad_tree_status=clean
fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh027\n'
    printf 'classification: runnable-ported\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'compile_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree_status: %s\n' "$fortad_tree_status"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'tapenade_transform_seconds_total: %s\n' "$tapenade_seconds"
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'upstream_program_strict_compile_status: %s\n' "$upstream_program_status"
    printf 'upstream_program_d_strict_compile_status: %s\n' "$upstream_d_status"
    printf 'upstream_program_b_strict_compile_status: %s\n' "$upstream_b_status"
    printf 'upstream_program_dv_strict_compile_status: %s\n' "$upstream_dv_status"
    printf 'stored_reference_messages: program_b.msg program_d.msg program_dv.msg\n'
    printf 'upstream_program_b_diagnostic: INTEGER*4 plus undeclared branch\n'
    printf 'upstream_program_dv_diagnostic: missing DIFFSIZES.inc\n'
    printf 'tapenade_generation: fresh parser, tangent, and reverse pass\n'
    printf 'tapenade_parser_strict_compile_status: %s\n' "$tapenade_parser_status"
    printf 'tapenade_forward_strict_compile_status: %s\n' "$tapenade_forward_status"
    printf 'tapenade_reverse_strict_compile_status: %s\n' "$tapenade_reverse_status"
    printf 'tapenade_reverse_diagnostic: INTEGER*4 plus undeclared branch\n'
    printf 'fortad_exact_forward_status: %s\n' "$fortad_exact_forward_status"
    printf 'fortad_exact_forward_compile_status: %s\n' \
        "$fortad_exact_forward_compile_status"
    printf 'fortad_exact_forward_diagnostic: generated source compiles but uses i uninitialized\n'
    printf 'fortad_exact_reverse_status: %s\n' "$fortad_exact_reverse_status"
    printf 'fortad_exact_reverse_diagnostic: %s\n' \
        "$(grep -F 'fortad:' "$out/exact/reverse.stderr" | tail -1)"
    printf 'fortad_port_forward_status: %s\n' "$fortad_port_forward_status"
    printf 'fortad_port_reverse_status: %s\n' "$fortad_port_reverse_status"
    printf 'fortad_port_generated_compile_statuses: forward %s reverse %s\n' \
        "$forward_status" "$reverse_status"
    printf 'port_compile_statuses: port %s hand %s harness %s\n' \
        "$port_status" "$hand_status" "$harness_status"
    printf 'independent_oracle: closed-form array/scalar JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/oracle/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    sha256sum "$source" "$upstream_dir/program_d.f" "$upstream_dir/program_b.f" \
        "$upstream_dir/program_dv.f" | sed "s#$tapenade_repo/##"
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh027.f90 \
        cases/tapenade-set01/hand_derivative_lh027.f90 \
        cases/tapenade-set01/lh027-manifest.toml \
        cases/tapenade-set01/lh027.md \
        harness/bench_tapenade_set01_lh027.f90 \
        scripts/bench_tapenade_set01_lh027.sh \
        scripts/test_tapenade_set01_lh027.py)
    printf 'oracle_output:\n'
    cat "$out/oracle/run.txt"
} >"$result"

cat "$result"
