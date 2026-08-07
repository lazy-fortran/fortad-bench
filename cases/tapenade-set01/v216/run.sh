#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set05/v216 no-entry boundary.
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
source_rel=nonRegressions/set05/v216
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

out=$(mktemp -d /var/tmp/fortad-bench-v216.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
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
    mkdir -p "$out/exact/mod-$label"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$out/exact/mod-$label" -c "$source" -o "$out/exact/$label.o"
}

compile_source upstream_primal "$source_dir/program.f90"
compile_source upstream_parser_reference "$source_dir/program_p.f90"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/upstream_parser_reference.status")" -eq 0
grep -Fq "Unused PRIVATE module variable" "$out/upstream_primal.stderr"
grep -Fq "Unused PRIVATE module variable" "$out/upstream_parser_reference.stderr"

for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -O . -o v216 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -e "$out/fresh/$mode/v216_${suffix}.msg"
done
test -s "$out/fresh/parser/v216_p.f90"
mkdir -p "$out/fresh/parser-mod"
run_status fresh_parser "$fc" "${strict_flags[@]}" -I"$source_dir" \
    -J"$out/fresh/parser-mod" -c "$out/fresh/parser/v216_p.f90" \
    -o "$out/fresh/parser.o"
test "$(cat "$out/fresh_parser.status")" -eq 0
for mode in forward reverse; do
    if test "$mode" = forward; then suffix=d; else suffix=b; fi
    test ! -e "$out/fresh/$mode/v216_${suffix}.f90"
    grep -Fq "No root unit to differentiate" "$out/fresh/$mode/v216_${suffix}.msg"
    grep -Fq "The code provided does not contain a top procedure" \
        "$out/fresh/$mode/v216_${suffix}.msg"
done

for mode in parser forward reverse; do
    case "$mode" in
        parser)
            run_status fortad-parser "$fortad" check \
                --output "$out/fortad-parser.f90" "$source_dir/program.f90"
            output="$out/fortad-parser.f90"
            ;;
        forward)
            run_status fortad-forward "$fortad" --mode forward --indep t \
                --name v216_jvp --module v216_jvp_mod \
                --output "$out/fortad-forward.f90" "$source_dir/program.f90"
            output="$out/fortad-forward.f90"
            ;;
        reverse)
            run_status fortad-reverse "$fortad" --mode reverse --indep t \
                --dep t --name v216_vjp --module v216_vjp_mod \
                --output "$out/fortad-reverse.f90" "$source_dir/program.f90"
            output="$out/fortad-reverse.f90"
            ;;
    esac
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$output"
    grep -Fq "fortad: no function or subroutine found in source" \
        "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" "$source_dir/program.f90" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set05/v216\n'
    printf 'classification: expected-refusal-no-entry-point-reference-only\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'source_checkout: %s\n' "$tapenade_repo"
    printf 'static_inventory: modules=definition,rk entries=none source=program.f90 stored_reference=program_p.f90\n'
    printf 'upstream_entry_point: none\n'
    printf 'selected_entry_points: none\n'
    printf 'tapenade_options: parser=-p/-O ./-o v216; forward=-d/-O ./-o v216; reverse=-b/-O ./-o v216; no root\n'
    printf 'upstream_exact_strict_compile: primal=%s parser_reference=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/upstream_parser_reference.status")"
    printf 'upstream_strict_diagnostic: pass with expected unused PRIVATE module variable warning\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v216_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=v216_p.msg tangent=v216_d.msg reverse=v216_b.msg\n'
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
    printf 'port_result: not-applicable-no-entry-point-reference-only\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 "$source_rel"/program_p.f90 "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v216_p.f90 parser/v216_p.msg forward/v216_d.msg reverse/v216_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
