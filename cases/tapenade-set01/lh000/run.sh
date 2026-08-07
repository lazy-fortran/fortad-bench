#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh000 empty-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
if test -n "${TAPENADE_REPO:-}"; then
    tapenade_repo=$TAPENADE_REPO
elif test -d "$root/upstream/tapenade/.git"; then
    tapenade_repo="$root/upstream/tapenade"
else
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade_repo/bin/tapenade"

source_dir="$tapenade_repo/nonRegressions/set01/lh000"
source_files=(program.f program.f90)
stored_messages=(program_b.msg program_bv.msg program_d.msg program_db.msg program_dv.msg program_p.msg)
for source in "${source_files[@]}"; do
    test -e "$source_dir/$source"
    test ! -s "$source_dir/$source"
done
for reference in "${stored_messages[@]}"; do
    test -e "$source_dir/$reference"
done

out=$(mktemp -d /var/tmp/fortad-bench-lh000.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/mod"

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
    run_status "$label" "$fc" "${strict_flags[@]}" -fsyntax-only -I"$source_dir" \
        -J"$out/mod" "$source"
}

for source in "${source_files[@]}"; do
    compile_source "upstream-${source//./-}" "$source_dir/$source"
    test "$(cat "$out/upstream-${source//./-}.status")" -eq 0
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

run_tapenade() {
    local label=$1
    local mode=$2
    local directory=$3
    run_status "tapenade-$label" bash -c \
        "cd '$directory' && '$tapenade_repo/bin/tapenade' '$mode' -O . -o lh000 '$source_dir/program.f'"
}

run_tapenade parser -p "$out/tapenade/parser"
run_tapenade tangent -d "$out/tapenade/forward"
run_tapenade reverse -b "$out/tapenade/reverse"
for label in parser tangent reverse; do
    test "$(cat "$out/tapenade-$label.status")" -eq 0
done

test -e "$out/tapenade/parser/lh000_p.msg"
test ! -e "$out/tapenade/parser/lh000_p.f"
test -s "$out/tapenade/forward/lh000_d.msg"
test -s "$out/tapenade/reverse/lh000_b.msg"
test ! -e "$out/tapenade/forward/lh000_d.f"
test ! -e "$out/tapenade/reverse/lh000_b.f"
grep -Fq "No root unit to differentiate" "$out/tapenade/forward/lh000_d.msg"
grep -Fq "The code provided does not contain a top procedure" "$out/tapenade/reverse/lh000_b.msg"
cmp -s "$out/tapenade/parser/lh000_p.msg" "$source_dir/program_p.msg"
cmp -s "$out/tapenade/forward/lh000_d.msg" "$source_dir/program_d.msg"
cmp -s "$out/tapenade/reverse/lh000_b.msg" "$source_dir/program_b.msg"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh000 empty-source boundary\n'
    printf 'classification: expected-refusal-no-entry-point\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: none (program.f and program.f90 are empty)\n'
    printf 'upstream_sources: program.f program.f90 (both exactly empty)\n'
    printf 'stored_references: program_p.msg program_d.msg program_db.msg program_dv.msg program_b.msg program_bv.msg\n'
    printf 'tapenade_options: parser=-p tangent=-d reverse=-b (no root; source has no top procedure)\n'
    printf 'upstream_exact_strict_compile: program.f=%s program.f90=%s\n' \
        "$(cat "$out/upstream-program-f.status")" "$(cat "$out/upstream-program-f90.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-tangent.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_sources: parser=none tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=lh000_p.msg tangent=lh000_d.msg reverse=lh000_b.msg\n'
    printf 'tapenade_fresh_strict_compile: not-applicable-no-fortran-source\n'
    printf 'tapenade_tangent_reverse_diagnostic: no-root-unit-and-no-top-procedure\n'
    printf 'fortad_exact_parser: not-applicable-no-entry-point\n'
    printf 'fortad_exact_forward: not-applicable-no-entry-point\n'
    printf 'fortad_exact_reverse: not-applicable-no-entry-point\n'
    printf 'fortad_generated_compile: not-applicable-no-entry-point\n'
    printf 'independent_semantic_oracle:\n'
    sed 's/^/  /' <<<"$oracle_output"
    printf 'port_result: not-claimed reason=empty-source-has-no-procedure-interface\n'
    printf 'closure: no bounded port; adding an entry point would invent missing semantics\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum nonRegressions/set01/lh000/program.f \
        nonRegressions/set01/lh000/program.f90 nonRegressions/set01/lh000/program_b.msg \
        nonRegressions/set01/lh000/program_bv.msg nonRegressions/set01/lh000/program_d.msg \
        nonRegressions/set01/lh000/program_db.msg nonRegressions/set01/lh000/program_dv.msg \
        nonRegressions/set01/lh000/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh000_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh000_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh000_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"

cat "$result"
