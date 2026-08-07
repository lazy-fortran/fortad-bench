#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set05/v146 no-entry boundary.
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

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set05/v146
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v146.XXXXXX)
trap 'rm -rf "$out"' EXIT

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

mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse"
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
for label in upstream_primal upstream_parser_reference; do
    test "$(cat "$out/$label.status")" -ne 0
    grep -Fq "Kind 2 not supported for type REAL" "$out/$label.stderr"
    grep -Fq "exponent and an explicit kind" "$out/$label.stderr"
done

for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -root A -O . -o v146 '$source_dir/program.f90'"
done
test "$(cat "$out/tapenade-parser-generation.status")" -eq 0
test "$(cat "$out/tapenade-forward-generation.status")" -eq 0
test "$(cat "$out/tapenade-reverse-generation.status")" -eq 0
test -s "$out/fresh/parser/v146_p.f90"
test -s "$out/fresh/parser/v146_p.msg"
test ! -e "$out/fresh/forward/v146_d.f90"
test -s "$out/fresh/forward/v146_d.msg"
test ! -e "$out/fresh/reverse/v146_b.f90"
test -s "$out/fresh/reverse/v146_b.msg"
grep -Fq "Can't differentiate a: is not a standard procedure" "$out/tapenade-parser-generation.stdout"
for mode in forward reverse; do
    grep -Fq "No root unit to differentiate" "$out/tapenade-$mode-generation.stdout"
    grep -Fq "code provided does not contain a top procedure" "$out/tapenade-$mode-generation.stdout"
done

compile_source fresh_parser "$out/fresh/parser/v146_p.f90"
test "$(cat "$out/fresh_parser.status")" -ne 0
grep -Fq "Kind 2 not supported for type REAL" "$out/fresh_parser.stderr"
grep -Fq "exponent and an explicit kind" "$out/fresh_parser.stderr"

for mode in parser forward reverse; do
    case "$mode" in
        parser) args=(check --proc A --output "$out/exact/fortad-parser.f90") ;;
        forward) args=(--mode forward --proc A --indep epsil --name v146_forward \
            --module v146_forward_mod --output "$out/exact/fortad-forward.f90") ;;
        reverse) args=(--mode reverse --proc A --indep epsil --dep epsil \
            --name v146_reverse --module v146_reverse_mod --output "$out/exact/fortad-reverse.f90") ;;
    esac
    run_status "fortad-$mode" "$fortad" "${args[@]}" "$source_dir/program.f90"
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/fortad-$mode.f90"
    grep -Fq "no procedure named 'A' in this source" "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" "$source_dir/program.f90" >"$out/oracle.txt"
grep -Fq "oracle_status: pass classification=module-only-no-entry-point" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set05/v146\n'
    printf 'classification: expected-refusal-no-entry-point-reference-only\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'static_inventory: module=A entries=none source=program.f90 stored_reference=program_p.f90\n'
    printf 'upstream_entry_point: none\n'
    printf 'tapenade_options: parser=-p/-root A forward=-d/-root A reverse=-b/-root A\n'
    printf 'upstream_exact_strict_compile: primal=%s parser_reference=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/upstream_parser_reference.status")"
    printf 'upstream_strict_diagnostic: Kind 2 not supported for type REAL; D exponent and an explicit kind\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v146_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=v146_p.msg tangent=v146_d.msg reverse=v146_b.msg\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_generation_diagnostic: parser=not-a-standard-procedure; tangent/reverse=no-root-unit\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="no procedure named A in this source"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="no procedure named A in this source"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="no procedure named A in this source"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: %s\n' "$(cat "$out/oracle.txt")"
    printf 'bounded_port: not-claimed reason=no-transformable-entry-point-and-no-repair-of-invalid-module\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f90 program_p.f90 program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v146_p.f90 v146_p.msg)
    (cd "$out/fresh/forward" && sha256sum v146_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v146_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
