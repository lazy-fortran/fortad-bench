#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set05/v201 no-entry boundary.
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
source_rel=nonRegressions/set05/v201
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
test ! -s "$source_dir/program_p.msg"
test ! -e "$source_dir/program_d.f90"
test ! -e "$source_dir/program_b.f90"

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
out=$(mktemp -d /var/tmp/fortad-bench-v201.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/stored" "$out/fresh/parser" \
    "$out/fresh/forward" "$out/fresh/reverse" "$out/fresh/parser-mod" \
    "$out/fortad"

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

compile_source upstream_primal "$source_dir/program.f90" "$out/exact/mod"
compile_source stored_parser "$source_dir/program_p.f90" "$out/stored/mod"
test "$(cat "$out/upstream_primal.status")" -ne 0
grep -Fq "Nonconforming tab character" "$out/upstream_primal.stderr"
grep -Fq "Nonstandard type declaration INTEGER*4" "$out/upstream_primal.stderr"
test "$(cat "$out/stored_parser.status")" -ne 0
grep -Fq "Nonstandard type declaration INTEGER*4" "$out/stored_parser.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/stored_parser.stderr"

generate_tapenade() {
    local label=$1
    local mode=$2
    local directory=$3
    run_status "tapenade-$label-generation" bash -c \
        "cd '$directory' && '$tapenade' '$mode' -O . -o v201 '$source_dir/program.f90'"
}

generate_tapenade parser -p "$out/fresh/parser"
generate_tapenade forward -d "$out/fresh/forward"
generate_tapenade reverse -b "$out/fresh/reverse"
for label in parser forward reverse; do
    test "$(cat "$out/tapenade-$label-generation.status")" -eq 0
done
test -s "$out/fresh/parser/v201_p.f90"
test -e "$out/fresh/parser/v201_p.msg"
test ! -e "$out/fresh/forward/v201_d.f90"
test -s "$out/fresh/forward/v201_d.msg"
test ! -e "$out/fresh/reverse/v201_b.f90"
test -s "$out/fresh/reverse/v201_b.msg"
grep -Fq "No root unit to differentiate" "$out/tapenade-forward-generation.stdout"
grep -Fq "The code provided does not contain a top procedure" \
    "$out/fresh/forward/v201_d.msg"
grep -Fq "No root unit to differentiate" "$out/tapenade-reverse-generation.stdout"
grep -Fq "The code provided does not contain a top procedure" \
    "$out/fresh/reverse/v201_b.msg"
cmp -s "$out/fresh/parser/v201_p.msg" "$source_dir/program_p.msg"
compile_source fresh_parser "$out/fresh/parser/v201_p.f90" "$out/fresh/parser-mod"
test "$(cat "$out/fresh_parser.status")" -ne 0
grep -Fq "Nonstandard type declaration INTEGER*4" "$out/fresh_parser.stderr"

run_status fortad-parser "$fortad" check --output "$out/fortad/parser.f90" \
    "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --indep acoef1 \
    --name v201_forward --module v201_forward_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --indep acoef1 \
    --dep acoef1 --name v201_reverse --module v201_reverse_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
for label in parser forward reverse; do
    test "$(cat "$out/fortad-$label.status")" -ne 0
    test ! -e "$out/fortad/$label.f90"
    grep -Fq "fortad: no function or subroutine found in source" \
        "$out/fortad-$label.stderr"
done

python3 "$case_dir/oracle.py" "$source_dir/program.f90" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set05/v201 module-only no-entry boundary\n'
    printf 'classification: expected-refusal-module-only-no-entry\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: none (MODULE TEST contains only module data declarations)\n'
    printf 'selected_entry_points: none\n'
    printf 'stored_references: program_p.f90 program_p.msg\n'
    printf 'missing_stored_references: program_d.f90 program_d.msg program_b.f90 program_b.msg\n'
    printf 'tapenade_options: parser=-p forward=-d reverse=-b (no root)\n'
    printf 'upstream_exact_strict_compile: program.f90=expected-refusal status=%s diagnostic="tabs and INTEGER*4/REAL*8 extensions"\n' \
        "$(cat "$out/upstream_primal.status")"
    printf 'stored_parser_strict_compile: expected-refusal status=%s diagnostic="Nonstandard type declaration INTEGER*4 and REAL*8"\n' \
        "$(cat "$out/stored_parser.status")"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v201_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=v201_p.msg tangent=v201_d.msg reverse=v201_b.msg\n'
    printf 'tapenade_fresh_strict_compile: parser=expected-refusal status=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_fresh_parser_diagnostic: Nonstandard type declaration INTEGER*4/REAL*8\n'
    printf 'tapenade_fresh_forward_reverse_diagnostic: No root unit to differentiate; no top procedure\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="fortad: no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="fortad: no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="fortad: no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_semantic_oracle:\n'
    sed 's/^/  /' "$out/oracle.txt"
    printf 'port_result: not-claimed reason=no-callable-entry-point\n'
    printf 'closure: module data only; no synthetic root or bounded derivative port\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 "$source_rel"/program_p.f90 \
        "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v201_p.f90 v201_p.msg)
    (cd "$out/fresh/forward" && sha256sum v201_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v201_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"

cat "$result"
