#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v547 boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=todoF90/REFERENCES/v547
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v547.XXXXXX)
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
for source in Options common.mod program.f90 program_p.f90 program_p.msg program_b.f90 program_b.msg; do
    test -s "$source_dir/$source"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact" "$out/exact-mod" "$out/fresh/p" "$out/fresh/d" "$out/fresh/b"

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

# Contract test 1: exact primal and all stored reference sources.
compile_source exact-primal "$source_dir/program.f90" "$out/exact-mod/primal"
compile_source exact-stored-parser "$source_dir/program_p.f90" "$out/exact-mod/parser"
compile_source exact-stored-reverse "$source_dir/program_b.f90" "$out/exact-mod/reverse"
test "$(cat "$out/exact-primal.status")" -eq 0
for label in exact-stored-parser exact-stored-reverse; do
    test "$(cat "$out/$label.status")" -ne 0
    grep -Fq "GNU Extension: Nonstandard type declaration" "$out/$label.stderr"
done

# Contract test 2: fresh pinned Tapenade generation and applicable strict compile.
for mode in p d b; do
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' -head 'endval(endval)/(bb)' \
         '-$mode' -O . -o v547 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v547_${mode}.f90"
    test -s "$out/fresh/$mode/v547_${mode}.msg"
    compile_source "fresh-$mode-compile" "$out/fresh/$mode/v547_${mode}.f90" \
        "$out/exact-mod/fresh-$mode"
    test "$(cat "$out/fresh-$mode-compile.status")" -ne 0
    grep -Fq "GNU Extension: Nonstandard type declaration" \
        "$out/fresh-$mode-compile.stderr"
done

# Contract test 3: exact FortAD parser, forward, and reverse refusal.
run_status fortad-parser "$fortad" check --proc endval \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --indep bb --dep endval \
    --proc endval --name v547_forward --module v547_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --indep bb --dep endval \
    --proc endval --name v547_reverse --module v547_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "Missing closing paren for binding label at line 62, column 25" \
        "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v547 endval declaration and binding-label boundary\n'
    printf 'classification: expected-refusal-invalid-stored-derivatives-and-fortad-binding-label\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: endval(bb,aind,bind,cind,n)\n'
    printf 'selected_entry_points: endval xmul xadd xdot\n'
    printf 'tapenade_options: -head endval(endval)/(bb); parser=-p tangent=-d reverse=-b\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_parser=%s stored_reverse=%s\n' \
        "$(cat "$out/exact-primal.status")" "$(cat "$out/exact-stored-parser.status")" \
        "$(cat "$out/exact-stored-reverse.status")"
    printf 'stored_reference_strict_diagnostic: legacy REAL*8/INTEGER*4 and declaration defects\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-p-generation.status")" \
        "$(cat "$out/tapenade-d-generation.status")" \
        "$(cat "$out/tapenade-b-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-p-compile.status")" "$(cat "$out/fresh-d-compile.status")" \
        "$(cat "$out/fresh-b-compile.status")"
    printf 'tapenade_fresh_strict_diagnostic: legacy kind declarations and generated declaration-order/intent defects\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="binding label line 62 column 25"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="binding label line 62 column 25"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="binding label line 62 column 25"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_indexed_array_oracle:\n'
    cat "$out/oracle.txt"
    printf 'port_result: not-claimed\n'
    printf 'closure: exact legacy declarations and FortAD binding-label parser boundary retained; no repaired port\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/common.mod \
        "$source_rel"/program.f90 "$source_rel"/program_p.f90 "$source_rel"/program_p.msg \
        "$source_rel"/program_b.f90 "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/p" && sha256sum v547_p.f90 v547_p.msg)
    (cd "$out/fresh/d" && sha256sum v547_d.f90 v547_d.msg)
    (cd "$out/fresh/b" && sha256sum v547_b.f90 v547_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
