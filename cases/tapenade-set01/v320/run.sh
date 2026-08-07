#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set06/v320 no-entry boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad/.git; then
    fortad_repo=/mnt/storage/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=3a946d34d3caa7a75fb6f891139023650b4ce51a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set06/v320
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in program.f90 program_p.f90 program_p.msg; do
    test -e "$source_dir/$source"
done
test -s "$source_dir/program.f90"
test -s "$source_dir/program_p.f90"

out=$(mktemp -d /var/tmp/fortad-bench-v320.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/fresh/parser-mod" "$out/fortad"
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source() {
    local label=$1
    local source=$2
    local module_dir=$3
    mkdir -p "$module_dir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$module_dir" -c "$source" -o "$out/$label.o"
}

compile_source upstream_primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source stored_parser "$source_dir/program_p.f90" "$out/exact/reference-mod"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/stored_parser.status")" -eq 0

for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -O . -o v320 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -e "$out/fresh/$mode/v320_${suffix}.msg"
done
test -s "$out/fresh/parser/v320_p.f90"
compile_source fresh_parser "$out/fresh/parser/v320_p.f90" "$out/fresh/parser-mod"
test "$(cat "$out/fresh_parser.status")" -eq 0
for mode in forward reverse; do
    suffix=d
    test "$mode" = reverse && suffix=b
    test ! -e "$out/fresh/$mode/v320_${suffix}.f90"
    grep -Fq "No root unit to differentiate" "$out/fresh/$mode/v320_${suffix}.msg"
    grep -Fq "The code provided does not contain a top procedure" \
        "$out/fresh/$mode/v320_${suffix}.msg"
done

run_status fortad-parser "$fortad" check \
    --output "$out/fortad/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --indep foobar \
    --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --indep foobar --dep foobar \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -eq 1
    test ! -e "$out/fortad/$mode.f90"
    grep -Fq "fortad: no function or subroutine found in source" \
        "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" "$source_dir/program.f90" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"
grep -Fq "callable_or_executable_units: 0" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set06/v320 module-only boundary\n'
    printf 'classification: expected-refusal-no-entry-point-module-only\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'source_checkout: %s\n' "$tapenade_repo"
    printf 'static_inventory: module=TEST_TYPEDEF foobar=private[2]=[0.0,1.0] types=Input,Output callable_units=0\n'
    printf 'upstream_entry_point: none\n'
    printf 'selected_entry_points: none\n'
    printf 'tapenade_options: parser=-p/-O ./-o v320; forward=-d/-O ./-o v320; reverse=-b/-O ./-o v320; no root\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_p.f90=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/stored_parser.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v320_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=v320_p.msg tangent=v320_d.msg reverse=v320_b.msg\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_no_root_diagnostic: forward="No root unit to differentiate; The code provided does not contain a top procedure" reverse="No root unit to differentiate; The code provided does not contain a top procedure"\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="fortad: no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="fortad: no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="fortad: no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-reverse.status")"
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-no-callable-procedure\n'
    printf 'closure: no synthetic root, wrapper, derivative port, or numerical runtime claim; module-only declaration domain\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 \
        "$source_rel"/program_p.f90 "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v320_p.f90 parser/v320_p.msg \
        forward/v320_d.msg reverse/v320_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
