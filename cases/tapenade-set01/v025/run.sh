#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set04/v025 no-entry boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set04/v025
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
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-v025.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact-mod" "$out/fresh/parser" "$out/fresh/parser-mod" \
    "$out/fresh/forward" "$out/fresh/reverse"
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
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
    local moddir=$3
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

compile_source exact_program "$source_dir/program.f90" "$out/exact-mod"
compile_source exact_parser_reference "$source_dir/program_p.f90" "$out/exact-mod"
test "$(cat "$out/exact_program.status")" -eq 0
test "$(cat "$out/exact_parser_reference.status")" -eq 0

for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -O . -o v025 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v025_${suffix}.msg"
done
test -s "$out/fresh/parser/v025_p.f90"
compile_source fresh_parser "$out/fresh/parser/v025_p.f90" "$out/fresh/parser-mod"
test "$(cat "$out/fresh_parser.status")" -eq 0
grep -Fq "No root unit to differentiate" "$out/fresh/forward/v025_d.msg"
grep -Fq "The code provided does not contain a top procedure" \
    "$out/fresh/forward/v025_d.msg"
grep -Fq "No root unit to differentiate" "$out/fresh/reverse/v025_b.msg"
grep -Fq "The code provided does not contain a top procedure" \
    "$out/fresh/reverse/v025_b.msg"

python3 "$case_dir/oracle.py" "$source_dir/program.f90" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set04/v025\n'
    printf 'classification: reference-only-no-entry-point\n'
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
    printf 'static_queue_category: no-entry-point-evidence\n'
    printf 'static_entry_point_hints: none\n'
    printf 'upstream_entry_points: none (modules a, b, c, d, e only)\n'
    printf 'selected_entry_points: none\n'
    printf 'tapenade_options: parser=-p/-O ./-o v025; forward=-d/-O ./-o v025; reverse=-b/-O ./-o v025; no root\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_p.f90=%s\n' \
        "$(cat "$out/exact_program.status")" "$(cat "$out/exact_parser_reference.status")"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v025_p.f90 forward=none reverse=none\n'
    printf 'tapenade_fresh_strict_compile: parser=%s forward=not-applicable reverse=not-applicable\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_no_root_diagnostic: forward="No root unit to differentiate; The code provided does not contain a top procedure" reverse="No root unit to differentiate; The code provided does not contain a top procedure"\n'
    printf 'fortad_exact_parser: not-applicable status=no-entry-point output=none\n'
    printf 'fortad_exact_forward: not-applicable status=no-entry-point output=none\n'
    printf 'fortad_exact_reverse: not-applicable status=no-entry-point output=none\n'
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-no-entry-point-reference-only\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 "$source_rel"/program_p.f90 "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v025_p.f90 parser/v025_p.msg \
        forward/v025_d.msg reverse/v025_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
