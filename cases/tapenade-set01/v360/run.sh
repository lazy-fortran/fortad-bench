#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set06/v360 no-entry boundary.
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
source_rel=nonRegressions/set06/v360
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
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in program.f90 program_p.f90 program_p.msg; do
    test -e "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-v360.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/fresh/parser-mod" "$out/fortad"

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
    local mod_dir=$3
    mkdir -p "$mod_dir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$mod_dir" -c "$source" -o "$out/$label.o"
}

compile_source exact_primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source exact_parser_reference "$source_dir/program_p.f90" "$out/exact/reference-mod"
test "$(cat "$out/exact_primal.status")" -eq 0
test "$(cat "$out/exact_parser_reference.status")" -eq 0
for diagnostic in "$out/exact_primal.stderr" "$out/exact_parser_reference.stderr"; do
    grep -Fq "Unused PRIVATE module variable" "$diagnostic"
    grep -Fq "gm_show" "$diagnostic"
    grep -Fq "gm_unit" "$diagnostic"
done

run_tapenade() {
    local mode=$1
    local flag=$2
    local status=0
    (cd "$out/fresh/$mode" && "$tapenade" "$flag" -O . -o v360 \
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
test -e "$out/fresh/parser/v360_p.msg"
test -s "$out/fresh/parser/v360_p.f90"
test ! -s "$out/fresh/parser/v360_p.msg"
test -s "$out/fresh/forward/v360_d.msg"
test -s "$out/fresh/reverse/v360_b.msg"
test ! -e "$out/fresh/forward/v360_d.f90"
test ! -e "$out/fresh/reverse/v360_b.f90"
for message in "$out/fresh/forward/v360_d.msg" "$out/fresh/reverse/v360_b.msg"; do
    grep -Fq "No root unit to differentiate" "$message"
    grep -Fq "The code provided does not contain a top procedure" "$message"
done

compile_source fresh_parser "$out/fresh/parser/v360_p.f90" "$out/fresh/parser-mod"
test "$(cat "$out/fresh_parser.status")" -eq 0
grep -Fq "Unused PRIVATE module variable" "$out/fresh_parser.stderr"
grep -Fq "gm_show" "$out/fresh_parser.stderr"
grep -Fq "gm_unit" "$out/fresh_parser.stderr"

fortad_probe() {
    local label=$1
    shift
    run_status "fortad-$label" "$fortad" "$@"
    test "$(cat "$out/fortad-$label.status")" -ne 0
    test ! -e "$out/fortad/$label.f90"
    test ! -s "$out/fortad-$label.stdout"
    grep -Fqx "fortad: no procedure named 'm0' in this source" \
        "$out/fortad-$label.stderr"
}

fortad_probe parser check --proc m0 --output "$out/fortad/parser.f90" \
    "$source_dir/program.f90"
fortad_probe forward --mode forward --proc m0 --indep m0_i \
    --name v360_forward --module v360_forward_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f90"
fortad_probe reverse --mode reverse --proc m0 --indep m0_i --dep m0_i \
    --name v360_reverse --module v360_reverse_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f90")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"
grep -Fqx "callable_or_executable_units: 0" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set06 v360 module-only boundary\n'
    printf 'classification: expected-refusal-no-callable-procedure-module-only\n'
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
    printf 'fortad_tracked_worktree: %s\n' "$(test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)" && echo clean || echo modified)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'source_checkout: %s\n' "$tapenade_repo"
    printf 'static_inventory: modules=M0,M1 uses=M1->M0 declarations=m0_i=2,gm_levels=6,gm_show=.false.,gm_unit=6 callable_units=0\n'
    printf 'upstream_entry_point: none (MODULE M0 and MODULE M1 only)\n'
    printf 'selected_entry_points: none\n'
    printf 'tapenade_options: parser=-p forward=-d reverse=-b; no root\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_p.f90=%s\n' \
        "$(cat "$out/exact_primal.status")" "$(cat "$out/exact_parser_reference.status")"
    printf 'upstream_strict_diagnostics: unused-private-module-variables-gm_show-and-gm_unit\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-forward.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_sources: parser=v360_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_no_root_diagnostic: tangent-and-reverse-message-only-no-root-no-top-procedure\n'
    printf 'fortad_exact_parser: expected-refusal status=%s stdout=empty stderr="no procedure named '\''m0'\'' in this source" output=none\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s stdout=empty stderr="no procedure named '\''m0'\'' in this source" output=none\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s stdout=empty stderr="no procedure named '\''m0'\'' in this source" output=none\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: module/use/declaration inventory and empty derivative domain\n'
    printf '%s\n' "$oracle_output"
    printf 'port_result: not-applicable-no-entry-point\n'
    printf 'closure: no synthetic root, wrapper, or derivative port; module-only declaration domain\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 \
        "$source_rel"/program_p.f90 "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v360_p.f90 v360_p.msg)
    (cd "$out/fresh/forward" && sha256sum v360_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v360_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v360/manifest.toml \
        cases/tapenade-set01/v360/notes.md cases/tapenade-set01/v360/oracle.py \
        cases/tapenade-set01/v360/run.sh cases/tapenade-set01/v360/test_contract.py)
} >"$result"
cat "$result"
