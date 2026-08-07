#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set04/v017 no-entry boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_checkout=$(printenv FORTAD_REPO 2>/dev/null || printf '%s' "$root/../fortad")
tapenade_repo=$(printenv TAPENADE_REPO 2>/dev/null || printf '%s' "$root/upstream/tapenade")
if test ! -e "$fortad_checkout/.git" && test -e /mnt/storage/code/lazy-fortran/fortad/.git; then
    fortad_checkout=/mnt/storage/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=$(printenv FC 2>/dev/null || printf '%s' gfortran)
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
source_dir="$tapenade_repo/nonRegressions/set04/v017"

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
test -e "$fortad_checkout/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_checkout" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in README program.f90 program_p.f90 program_p.msg; do
    test -e "$source_dir/$source"
done
test -x "$tapenade_repo/bin/tapenade"

out=$(mktemp -d /var/tmp/fortad-bench-v017.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod/primal" "$out/mod/stored" "$out/mod/fresh" \
    "$out/tapenade/parser" "$out/tapenade/tangent" "$out/tapenade/reverse"

compile_source() {
    local source=$1 label=$2 mod_dir=$3
    set +e
    "$fc" -std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
        -Wall -Wextra -Wimplicit-interface -cpp \
        -J"$mod_dir" -I"$mod_dir" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source "$source_dir/program.f90" upstream_primal "$out/mod/primal"
compile_source "$source_dir/program_p.f90" stored_parser "$out/mod/stored"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/stored_parser.status")" -ne 0
grep -Fq "SEQUENCE PRIVATE" "$out/stored_parser.stderr"
grep -Fq "PRIVATE SEQUENCE" "$out/stored_parser.stderr"

run_tapenade() {
    local mode=$1
    local flag=$2
    set +e
    (cd "$tapenade_repo" && "$tapenade_repo/bin/tapenade" "$flag" \
        -O "$out/tapenade/$mode" -o v017 "$source_dir/program.f90") \
        >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/tapenade-$mode.status"
}

run_tapenade parser -p
run_tapenade tangent -d
run_tapenade reverse -b
for mode in parser tangent reverse; do
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
done
test -s "$out/tapenade/parser/v017_p.f90"
test -e "$out/tapenade/parser/v017_p.msg"
test -e "$out/tapenade/tangent/v017_d.msg"
test -e "$out/tapenade/reverse/v017_b.msg"
grep -Fq "No root unit to differentiate" "$out/tapenade-tangent.stdout"
grep -Fq "The code provided does not contain a top procedure" "$out/tapenade-tangent.stdout"
grep -Fq "No root unit to differentiate" "$out/tapenade-reverse.stdout"
grep -Fq "The code provided does not contain a top procedure" "$out/tapenade-reverse.stdout"
compile_source "$out/tapenade/parser/v017_p.f90" fresh_parser "$out/mod/fresh"
test "$(cat "$out/fresh_parser.status")" -ne 0
grep -Fq "SEQUENCE PRIVATE" "$out/fresh_parser.stderr"
grep -Fq "PRIVATE SEQUENCE" "$out/fresh_parser.stderr"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set04 v017\n'
    printf 'classification: no-entry-point-source-module\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: -std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp\n'
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_checkout" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: none\n'
    printf 'static_extractor_boundary: no program/subroutine/function declaration\n'
    printf 'upstream_exact_strict_compile: %s\n' "$(cat "$out/upstream_primal.status")"
    printf 'stored_program_p_strict_compile: expected-refusal SEQUENCE PRIVATE and PRIVATE SEQUENCE\n'
    printf 'tapenade_parser_generation: %s\n' "$(cat "$out/tapenade-parser.status")"
    printf 'tapenade_parser_fresh_strict_compile: expected-refusal SEQUENCE PRIVATE and PRIVATE SEQUENCE\n'
    printf 'tapenade_tangent_generation: %s\n' "$(cat "$out/tapenade-tangent.status")"
    printf 'tapenade_tangent_output: message-only-no-root-no-top-procedure\n'
    printf 'tapenade_reverse_generation: %s\n' "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_reverse_output: message-only-no-root-no-top-procedure\n'
    printf 'fortad_exact_parser: not-run-no-entry-point\n'
    printf 'fortad_exact_forward: not-run-no-entry-point\n'
    printf 'fortad_exact_reverse: not-run-no-entry-point\n'
    printf 'fortad_boundary: exact requests are inapplicable; no selected entry point and no refusal location exists\n'
    printf 'independent_oracle: module declaration inventory, COMMON layout, and executable-unit absence\n'
    printf '%s\n' "$oracle_output"
    printf 'numerical_oracle: not-applicable-no-executable-observable\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum README program.f90 program_p.f90 program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum v017_p.f90 v017_p.msg)
    (cd "$out/tapenade/tangent" && sha256sum v017_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum v017_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v017/manifest.toml \
        cases/tapenade-set01/v017/notes.md cases/tapenade-set01/v017/oracle.py \
        cases/tapenade-set01/v017/run.sh cases/tapenade-set01/v017/test_contract.py)
} >"$result"
cat "$result"
