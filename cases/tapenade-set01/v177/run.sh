#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set05/v177 no-entry boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=3a946d34d3caa7a75fb6f891139023650b4ce51a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set05/v177
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
for absent in program_d.f90 program_d.msg program_b.f90 program_b.msg; do
    test ! -e "$source_dir/$absent"
done
test "$(git -C "$tapenade_repo" ls-files "$source_rel" | tr '\n' ' ')" = \
    "${source_rel}/program.f90 ${source_rel}/program_p.f90 ${source_rel}/program_p.msg "

out=$(mktemp -d /var/tmp/fortad-bench-v177.XXXXXX)
mkdir -p "$out/exact/mod" "$out/fresh/parser" "$out/fresh/tangent" \
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

compile_source exact-primal "$source_dir/program.f90" "$out/exact/mod"
compile_source stored-parser "$source_dir/program_p.f90" "$out/exact/mod"
test "$(cat "$out/exact-primal.status")" -eq 1
test "$(cat "$out/stored-parser.status")" -eq 1
grep -Fq "Nonconforming tab character" "$out/exact-primal.stderr"
grep -Fq "Nonstandard type declaration" "$out/exact-primal.stderr"
grep -Fq "Nonstandard type declaration" "$out/stored-parser.stderr"

run_status tapenade-parser bash -c \
    "cd '$out/fresh/parser' && '$tapenade' -p -O . -o v177_p '$source_dir/program.f90'"
run_status tapenade-tangent bash -c \
    "cd '$out/fresh/tangent' && '$tapenade' -d -O . -o v177_d '$source_dir/program.f90'"
run_status tapenade-reverse bash -c \
    "cd '$out/fresh/reverse' && '$tapenade' -b -O . -o v177_b '$source_dir/program.f90'"
for mode in parser tangent reverse; do
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
done
test -s "$out/fresh/parser/v177_p_p.f90"
test -e "$out/fresh/parser/v177_p_p.msg"
test ! -e "$out/fresh/tangent/v177_d_d.f90"
test -s "$out/fresh/tangent/v177_d_d.msg"
test ! -e "$out/fresh/reverse/v177_b_b.f90"
test -s "$out/fresh/reverse/v177_b_b.msg"
grep -Fq "No root unit to differentiate" "$out/fresh/tangent/v177_d_d.msg"
grep -Fq "The code provided does not contain a top procedure" \
    "$out/fresh/reverse/v177_b_b.msg"
compile_source fresh-parser "$out/fresh/parser/v177_p_p.f90" "$out/fresh/parser-mod"
test "$(cat "$out/fresh-parser.status")" -eq 1
grep -Fq "Nonstandard type declaration" "$out/fresh-parser.stderr"

run_status fortad-parser "$fortad" check \
    --output "$out/fortad/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --indep X \
    --name v177_forward --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --indep X --dep Y \
    --name v177_reverse --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -eq 1
    test ! -e "$out/fortad/$mode.f90"
    grep -Fq "fortad: no function or subroutine found in source" \
        "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fqx "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set05/v177 module-only no-entry boundary\n'
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
    printf 'upstream_entry_point: none (module mcrm2par; no function, subroutine, or program)\n'
    printf 'stored_references: program_p.f90 program_p.msg\n'
    printf 'missing_stored_references: program_d.f90 program_d.msg program_b.f90 program_b.msg\n'
    printf 'tapenade_options: parser=-p tangent=-d reverse=-b (no root; source has no top procedure)\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_p.f90=%s\n' \
        "$(cat "$out/exact-primal.status")" "$(cat "$out/stored-parser.status")"
    printf 'upstream_strict_diagnostic: primal=nonconforming-tabs-and-nonstandard-types stored-parser=nonstandard-types\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-tangent.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_sources: parser=v177_p_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=v177_p_p.msg tangent=v177_d_d.msg reverse=v177_b_b.msg\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh-parser.status")"
    printf 'tapenade_tangent_reverse_diagnostic: No root unit to differentiate; The code provided does not contain a top procedure\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_semantic_oracle:\n'
    sed 's/^/  /' "$out/oracle.txt"
    printf 'port_result: not-claimed reason=no-callable-procedure-interface\n'
    printf 'closure: module-only source; no synthetic root or derivative port\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 \
        "$source_rel"/program_p.f90 "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v177_p_p.f90 v177_p_p.msg)
    (cd "$out/fresh/tangent" && sha256sum v177_d_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v177_b_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"

cat "$result"
