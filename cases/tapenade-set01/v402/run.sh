#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v402 invalid-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-}
if test -z "$tapenade_repo"; then
    if test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstreams/tapenade-e59864c/.git; then
        tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstreams/tapenade-e59864c
    else
        tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
    fi
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=todoF90/REFERENCES/v402
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
for source in program.f90 program_b.f90 program_b.msg; do
    test -s "$source_dir/$source"
done
test -x "$fortad"
test -x "$tapenade"

out=$(mktemp -d /var/tmp/fortad-bench-v402.XXXXXX)
mkdir -p "$out/exact-mod" "$out/fresh/parser" "$out/fresh/parser-mod" \
    "$out/fresh/forward" "$out/fresh/forward-mod" "$out/fresh/reverse" \
    "$out/fresh/reverse-mod" "$out/exact"
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
    local moddir=$3
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

compile_source exact_program "$source_dir/program.f90" "$out/exact-mod"
compile_source exact_reverse "$source_dir/program_b.f90" "$out/exact-mod"
test "$(cat "$out/exact_program.status")" -ne 0
test "$(cat "$out/exact_reverse.status")" -ne 0
grep -Fq "Nonstandard type declaration REAL*8" "$out/exact_program.stderr"
if ! grep -Eq "diffsizes\.mod|Nonstandard type declaration REAL\\*8" \
    "$out/exact_reverse.stderr"; then
    exit 1
fi
test ! -e "$source_dir/diffsizes.f90"
test ! -e "$source_dir/DIFFSIZES.f90"

for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -root timeloop -O . -o v402 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v402_${suffix}.f90"
    test -s "$out/fresh/$mode/v402_${suffix}.msg"
    compile_source "fresh_$mode" "$out/fresh/$mode/v402_${suffix}.f90" \
        "$out/fresh/$mode-mod"
    test "$(cat "$out/fresh_$mode.status")" -ne 0
    grep -Fq "Nonstandard type declaration REAL*8" "$out/fresh_$mode.stderr"
done

run_status fortad-parser "$fortad" check --proc timeloop \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --proc timeloop --indep k \
    --name v402_forward --module v402_forward_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --proc timeloop --indep k --dep a \
    --name v402_reverse --module v402_reverse_mod --output "$out/exact/reverse.f90" \
    "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component' at line 12" \
        "$out/fortad-$mode.stderr"
done

TAPENADE_REPO="$tapenade_repo" python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90/REFERENCES/v402\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
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
    printf 'upstream_entry_points: timeloop(k); f(a); g(a)\n'
    printf 'tapenade_options: parser=-p/-root timeloop forward=-d/-root timeloop reverse=-b/-root timeloop\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_b.f90=%s\n' \
        "$(cat "$out/exact_program.status")" "$(cat "$out/exact_reverse.status")"
    printf 'upstream_diagnostics: program.f90="%s" program_b.f90="%s"\n' \
        "$(grep -E 'Error:|Fatal Error:' "$out/exact_program.stderr" | head -1 | sed 's/^[[:space:]]*//')" \
        "$(grep -E 'Error:|Fatal Error:' "$out/exact_reverse.stderr" | head -1 | sed 's/^[[:space:]]*//')"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v402_p.f90 forward=v402_d.f90 reverse=v402_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" "$(cat "$out/fresh_forward.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="allocatable declaration/component line 12"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="allocatable declaration/component line 12"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="allocatable declaration/component line 12"\n' \
        "$(cat "$out/fortad-reverse.status")"
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-invalid-source-no-standard-conforming-map\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 "$source_rel"/program_b.f90 "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v402_p.f90 parser/v402_p.msg \
        forward/v402_d.f90 forward/v402_d.msg reverse/v402_b.f90 reverse/v402_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
