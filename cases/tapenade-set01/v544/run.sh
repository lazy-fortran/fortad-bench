#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set07/v544 no-entry boundary.
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
source_rel=nonRegressions/set07/v544
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
for source in program.f90 program_p.f90 program_p.msg; do
    test -e "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-v544.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/fortad"

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)

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

# Contract 1: exact source and stored parser reference compile strictly.
compile_source exact-source "$source_dir/program.f90" "$out/exact/source-mod"
compile_source exact-parser-reference "$source_dir/program_p.f90" \
    "$out/exact/parser-mod"
test "$(cat "$out/exact-source.status")" -eq 0
test "$(cat "$out/exact-parser-reference.status")" -eq 0
test ! -s "$source_dir/program_p.msg"

# Contract 2: fresh pinned Tapenade parser, tangent, and reverse no-root probes.
run_tapenade() {
    local mode=$1
    local flag=$2
    local status=0
    (cd "$out/fresh/$mode" && "$tapenade" "$flag" -O . -o v544 \
        "$source_dir/program.f90") >"$out/tapenade-$mode.stdout" \
        2>"$out/tapenade-$mode.stderr" || status=$?
    printf '%s\n' "$status" >"$out/tapenade-$mode.status"
}

run_tapenade parser -p
run_tapenade forward -d
run_tapenade reverse -b
for mode in parser forward reverse; do
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
done
test -s "$out/fresh/parser/v544_p.f90"
test -e "$out/fresh/parser/v544_p.msg"
test ! -s "$out/fresh/parser/v544_p.msg"
test -s "$out/fresh/forward/v544_d.msg"
test -s "$out/fresh/reverse/v544_b.msg"
test ! -e "$out/fresh/forward/v544_d.f90"
test ! -e "$out/fresh/reverse/v544_b.f90"
for message in "$out/fresh/forward/v544_d.msg" "$out/fresh/reverse/v544_b.msg"; do
    grep -Fq "No root unit to differentiate" "$message"
    grep -Fq "The code provided does not contain a top procedure" "$message"
done
compile_source fresh-parser "$out/fresh/parser/v544_p.f90" "$out/fresh/parser-mod"
test "$(cat "$out/fresh-parser.status")" -eq 0

# Contract 3: FortAD refuses all three requests because there is no procedure.
fortad_probe() {
    local label=$1
    shift
    run_status "fortad-$label" "$fortad" "$@" "$source_dir/program.f90"
    test "$(cat "$out/fortad-$label.status")" -ne 0
    test ! -e "$out/fortad/$label.f90"
    test ! -s "$out/fortad-$label.stdout"
    grep -Fqx "fortad: no function or subroutine found in source" \
        "$out/fortad-$label.stderr"
}

fortad_probe parser check --output "$out/fortad/parser.f90"
fortad_probe forward --mode forward --indep ptr --name v544_forward \
    --module v544_forward_mod --output "$out/fortad/forward.f90"
fortad_probe reverse --mode reverse --indep ptr --dep ptr --name v544_reverse \
    --module v544_reverse_mod --output "$out/fortad/reverse.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f90")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"
grep -Fqx "callable_or_executable_units: 0" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set07 v544 module-only boundary\n'
    printf 'classification: expected-refusal-no-callable-procedure-module-only\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_tracked_worktree: %s\n' "$(test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)" && echo clean || echo modified)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'source_checkout: %s\n' "$tapenade_repo"
    printf 'static_inventory: module=TEST C_INTPTR_T=4 C_PTR%%ptr=private-integer C_NULL_PTR=C_PTR(0) callable_units=0\n'
    printf 'upstream_entry_point: none (MODULE TEST only)\n'
    printf 'selected_entry_points: none\n'
    printf 'tapenade_options: parser=-p forward=-d reverse=-b; no root\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_p.f90=%s\n' \
        "$(cat "$out/exact-source.status")" "$(cat "$out/exact-parser-reference.status")"
    printf 'stored_parser_message: empty\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-forward.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_sources: parser=v544_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh-parser.status")"
    printf 'tapenade_no_root_diagnostic: tangent-and-reverse-message-only-no-root-no-top-procedure\n'
    printf 'fortad_exact_parser: expected-refusal status=%s diagnostic="no function or subroutine found in source" output=none\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="no function or subroutine found in source" output=none\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="no function or subroutine found in source" output=none\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: module/type/declaration inventory and empty derivative domain\n'
    printf '%s\n' "$oracle_output"
    printf 'port_result: not-applicable-no-callable-procedure\n'
    printf 'closure: no synthetic root, wrapper, or derivative port; module-only declaration domain\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 \
        "$source_rel"/program_p.f90 "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v544_p.f90 v544_p.msg)
    (cd "$out/fresh/forward" && sha256sum v544_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v544_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
