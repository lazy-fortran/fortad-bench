#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v505 callback boundary.
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
source_rel=todoF90/REFERENCES/v505
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v505.XXXXXX)
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
for present in program.f90 program_d.f90 program_d.msg; do
    test -s "$source_dir/$present"
done
for absent in program_p.f90 program_p.msg program_b.f90 program_b.msg; do
    test ! -e "$source_dir/$absent"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact" "$out/exact/primal-mod" "$out/exact/stored-mod"     "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"     "$out/fresh/parser-mod" "$out/fresh/forward-mod" "$out/fresh/reverse-mod"

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
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir"         -J"$module_dir" -c "$source" -o "$out/$label.o"
}

# Contract test 1: exact primal and stored tangent reference compile strictly.
compile_source exact-primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source exact-stored-tangent "$source_dir/program_d.f90" "$out/exact/stored-mod"
test "$(cat "$out/exact-primal.status")" -eq 0
test "$(cat "$out/exact-stored-tangent.status")" -eq 0
grep -Fq "ftest" "$out/exact-primal.stderr"
grep -Fq "ftest_d" "$out/exact-stored-tangent.stderr"

# Contract test 2: fresh pinned Tapenade generation and strict compilation.
for mode in parser forward reverse; do
    case "$mode" in
        parser) tapenade_mode=-p; suffix=p ;;
        forward) tapenade_mode=-d; suffix=d ;;
        reverse) tapenade_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c         "cd '$out/fresh/$mode' && '$tapenade' '$tapenade_mode' -root top          -O . -o v505 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v505_${suffix}.f90"
    test -s "$out/fresh/$mode/v505_${suffix}.msg"
    compile_source "fresh-$mode" "$out/fresh/$mode/v505_${suffix}.f90"         "$out/fresh/${mode}-mod"
    test "$(cat "$out/fresh-$mode.status")" -eq 0
done
grep -Fq "External routine ftest" "$out/fresh/parser/v505_p.msg"
grep -Fq "Please provide a differential of function ftest"     "$out/fresh/forward/v505_d.msg"
grep -Fq "Please provide a differential of function ftest"     "$out/fresh/reverse/v505_b.msg"

# Contract test 3: exact FortAD parser, forward, and reverse refusal, plus the
# independent callback-graph semantic oracle.
run_status fortad-parser "$fortad" check --proc top     --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --indep r,s --dep top     --proc top --name v505_forward --module v505_forward_mod     --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --indep r,s --dep top     --proc top --name v505_reverse --module v505_reverse_mod     --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "unsupported statement at line 12" "$out/fortad-$mode.stderr"
done
python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v505 external-callback interface boundary\n'
    printf 'classification: expected-refusal-without-bounded-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: top(r,s)\n'
    printf 'ported_entry_point: not-claimed-underdetermined-external-callback\n'
    printf 'stored_references: program_d.f90 program_d.msg\n'
    printf 'missing_stored_references: program_p.f90 program_p.msg program_b.f90 program_b.msg\n'
    printf 'tapenade_options: parser=-p/-root top forward=-d/-root top reverse=-b/-root top\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_tangent=%s\n'         "$(cat "$out/exact-primal.status")" "$(cat "$out/exact-stored-tangent.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n'         "$(cat "$out/tapenade-parser-generation.status")"         "$(cat "$out/tapenade-forward-generation.status")"         "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n'         "$(cat "$out/fresh-parser.status")" "$(cat "$out/fresh-forward.status")"         "$(cat "$out/fresh-reverse.status")"
    printf 'tapenade_fresh_messages: parser=external-ftest-activity tangent=missing-ftest-differential reverse=missing-ftest-differential\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="unsupported statement at line 12"\n'         "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="unsupported statement at line 12"\n'         "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="unsupported statement at line 12"\n'         "$(cat "$out/fortad-reverse.status")"
    printf 'independent_semantic_oracle:\n'
    cat "$out/oracle.txt"
    printf 'port_result: not-claimed\n'
    printf 'closure: exact source delegates its value to absent external ftest and compute implementations; no numerical port is defined\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel/program.f90" "$source_rel/program_d.f90" "$source_rel/program_d.msg")
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v505_p.f90 v505_p.msg)
    (cd "$out/fresh/forward" && sha256sum v505_d.f90 v505_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v505_b.f90 v505_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
