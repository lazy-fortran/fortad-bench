#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v503 boundary.
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
source_rel=todoF90/REFERENCES/v503
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v503.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT

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
test -s "$source_dir/program.f90"
for absent in Options program_d.f90 program_d.msg program_b.f90 program_b.msg; do
    test ! -e "$source_dir/$absent"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact" "$out/exact-mod" "$out/fresh/parser" \
    "$out/fresh/forward" "$out/fresh/reverse" "$out/fresh/parser-mod"

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

# Contract test 1: exact source, strict refusal, and absence of stored refs.
compile_source exact-upstream "$source_dir/program.f90" "$out/exact-mod"
test "$(cat "$out/exact-upstream.status")" -ne 0
grep -Fq "Allocate-object" "$out/exact-upstream.stderr"
grep -Fq "neither a data pointer nor an allocatable variable" "$out/exact-upstream.stderr"

# Contract test 2: fresh pinned Tapenade generation and applicable compiles.
for mode in parser forward reverse; do
    case "$mode" in
        parser) tapenade_mode=-p; suffix=p ;;
        forward) tapenade_mode=-d; suffix=d ;;
        reverse) tapenade_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tapenade_mode' -root SYSTEME \
         -O . -o v503 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v503_${suffix}.msg"
done
test -s "$out/fresh/parser/v503_p.f90"
test ! -e "$out/fresh/forward/v503_d.f90"
test ! -e "$out/fresh/reverse/v503_b.f90"
compile_source fresh-tapenade-parser "$out/fresh/parser/v503_p.f90" \
    "$out/fresh/parser-mod"
test "$(cat "$out/fresh-tapenade-parser.status")" -ne 0
grep -Fq "not a variable" "$out/fresh-tapenade-parser.stderr"
grep -Fq "not been declared" "$out/fresh-tapenade-parser.stderr"
grep -Fq "no active input nor output" "$out/fresh/forward/v503_d.msg"
grep -Fq "no active input nor output" "$out/fresh/reverse/v503_b.msg"

# Contract test 3: exact FortAD parser, forward, and reverse refusal.
run_status fortad-parser "$fortad" check --proc SYSTEME \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --indep X --dep Q \
    --proc SYSTEME --name v503_forward --module v503_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --indep X --dep Q \
    --proc SYSTEME --name v503_reverse --module v503_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocate' at line 80" \
        "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v503 incomplete SYSTEME boundary\n'
    printf 'classification: expected-refusal-invalid-incomplete-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: SYSTEME\n'
    printf 'stored_references: none-present\n'
    printf 'missing_stored_references: Options program_d.f90 program_d.msg program_b.f90 program_b.msg\n'
    printf 'tapenade_options: parser=-p/-root SYSTEME forward=-d/-root SYSTEME reverse=-b/-root SYSTEME\n'
    printf 'upstream_exact_strict_compile: expected-refusal status=%s diagnostic="Allocate-object is neither a data pointer nor an allocatable variable"\n' \
        "$(cat "$out/exact-upstream.status")"
    printf 'stored_reference_strict_compile: not-applicable no-stored-reference\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v503_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=v503_p.msg tangent=v503_d.msg reverse=v503_b.msg\n'
    printf 'tapenade_fresh_strict_compile: parser=expected-refusal status=%s tangent=not-applicable reverse=not-applicable\n' \
        "$(cat "$out/fresh-tapenade-parser.status")"
    printf 'tapenade_parser_strict_diagnostic: undeclared allocation targets and invalid SELECT CASE constants\n'
    printf 'tapenade_tangent_reverse_diagnostic: AD06 differentiation root procedures have no active input nor output\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocate at line 80"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocate at line 80"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocate at line 80"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_semantic_oracle:\n'
    cat "$out/oracle.txt"
    printf 'port_result: not-claimed\n'
    printf 'closure: invalid incomplete source; no declarations, project interfaces, or initial state available for a bounded port\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel/program.f90")
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v503_p.f90 v503_p.msg)
    (cd "$out/fresh/forward" && sha256sum v503_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v503_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
