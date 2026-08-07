#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set11/vpf16 module-only boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-$root/upstream/tapenade}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=3a946d34d3caa7a75fb6f891139023650b4ce51a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set11/vpf16
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in Options program.f90 program_p.f90 program_p.msg; do
    test -e "$source_dir/$source"
done
test ! -e "$source_dir/program_d.f90"
test ! -e "$source_dir/program_b.f90"
test "$(tr -d '\r\n' < "$source_dir/Options")" = "-msginfile -noinclude -noisize"

out=$(mktemp -d /var/tmp/fortad-bench-vpf16.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/stored" "$out/fresh/parser" \
    "$out/fresh/forward" "$out/fresh/reverse" "$out/fortad"

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

# Contract test 1: exact source and stored parser reference compile strictly.
compile_source exact_program "$source_dir/program.f90" "$out/exact/mod"
compile_source stored_parser "$source_dir/program_p.f90" "$out/stored/mod"
test "$(cat "$out/exact_program.status")" -eq 0
test "$(cat "$out/stored_parser.status")" -eq 0

# Contract test 2: parser emits a module; AD modes have no root procedure.
for mode in parser forward reverse; do
    case "$mode" in
        parser) tapenade_mode=-p; suffix=p ;;
        forward) tapenade_mode=-d; suffix=d ;;
        reverse) tapenade_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$source_dir' && '$tapenade' '$tapenade_mode' -O '$out/fresh/$mode' -o vpf16 program.f90"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -e "$out/fresh/$mode/vpf16_${suffix}.msg"
done
test -s "$out/fresh/parser/vpf16_p.f90"
test ! -e "$out/fresh/forward/vpf16_d.f90"
test ! -e "$out/fresh/reverse/vpf16_b.f90"
test ! -s "$out/fresh/parser/vpf16_p.msg"
grep -Fq "No root unit to differentiate" "$out/fresh/forward/vpf16_d.msg"
grep -Fq "The code provided does not contain a top procedure" "$out/fresh/forward/vpf16_d.msg"
grep -Fq "No root unit to differentiate" "$out/fresh/reverse/vpf16_b.msg"
grep -Fq "The code provided does not contain a top procedure" "$out/fresh/reverse/vpf16_b.msg"
compile_source fresh_parser "$out/fresh/parser/vpf16_p.f90" "$out/fresh/parser/mod"
test "$(cat "$out/fresh_parser.status")" -eq 0

# Contract test 3: exact FortAD no-entry refusal in all three modes.
run_status fortad-parser "$fortad" check \
    --output "$out/fortad/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --proc esmf_calendarmod \
    --indep esmf_calendar_dummy --name vpf16_forward --module vpf16_forward_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --proc esmf_calendarmod \
    --indep esmf_calendar_dummy --dep esmf_calendar_dummy --name vpf16_reverse \
    --module vpf16_reverse_mod --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-parser.status")" -eq 1
test "$(cat "$out/fortad-forward.status")" -eq 1
test "$(cat "$out/fortad-reverse.status")" -eq 1
test ! -e "$out/fortad/parser.f90"
test ! -e "$out/fortad/forward.f90"
test ! -e "$out/fortad/reverse.f90"
grep -Fqx "fortad: no function or subroutine found in source" "$out/fortad-parser.stderr"
grep -Fqx "fortad: no procedure named 'esmf_calendarmod' in this source" "$out/fortad-forward.stderr"
grep -Fqx "fortad: no procedure named 'esmf_calendarmod' in this source" "$out/fortad-reverse.stderr"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f90")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"
grep -Fqx "oracle_entry_points: none" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set11/vpf16 module-only/no-entry boundary\n'
    printf 'classification: expected-refusal-module-only-no-entry\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'source_checkout: %s\n' "$tapenade_repo"
    printf 'upstream_entry_point: none (ESMF_CalendarMod and mo are declaration-only modules)\n'
    printf 'selected_entry_points: none\n'
    printf 'options_metadata: %s\n' "$(tr -d '\r\n' < "$source_dir/Options")"
    printf 'stored_references: program_p.f90 program_p.msg\n'
    printf 'missing_stored_references: program_d.f90 program_d.msg program_b.f90 program_b.msg\n'
    printf 'tapenade_options: parser=-p forward=-d reverse=-b; source Options metadata above; no -root/-head\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_p.f90=%s\n' \
        "$(cat "$out/exact_program.status")" "$(cat "$out/stored_parser.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=vpf16_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=vpf16_p.msg tangent=vpf16_d.msg reverse=vpf16_b.msg\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_tangent_reverse_diagnostic: no root unit to differentiate; code provided does not contain a top procedure\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="no procedure named '\''esmf_calendarmod'\'' in this source"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="no procedure named '\''esmf_calendarmod'\'' in this source"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_semantic_oracle:\n'
    sed 's/^/  /' <<<"$oracle_output"
    printf 'port_result: not-claimed reason=module-only-source-has-no-procedure-entry\n'
    printf 'synthetic_root: none\n'
    printf 'derivative_port: none\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f90 \
        "$source_rel"/program_p.f90 "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum vpf16_p.f90 vpf16_p.msg)
    (cd "$out/fresh/forward" && sha256sum vpf16_d.msg)
    (cd "$out/fresh/reverse" && sha256sum vpf16_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
