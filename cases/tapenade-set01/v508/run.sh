#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v508 boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=todoF90/REFERENCES/v508
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v508.XXXXXX)
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
for source in Options m.mod program.f90 program_d.f90 program_d.msg; do
    test -s "$source_dir/$source"
done
for absent in program_p.f90 program_p.msg program_b.f90 program_b.msg; do
    test ! -e "$source_dir/$absent"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact/primal-mod" "$out/exact/stored-mod" \
    "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" \
    "$out/fresh/parser-mod" "$out/fresh/forward-mod" "$out/fresh/reverse-mod" \
    "$out/fortad/parser-mod" "$out/fortad/forward-mod"

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
    local moddir=$3
    shift 3
    mkdir -p "$moddir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" "$@" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

# Contract test 1: compile the exact primal and stored tangent.
compile_source upstream-primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source upstream-stored "$source_dir/program_d.f90" "$out/exact/stored-mod"
test "$(cat "$out/upstream-primal.status")" -eq 0
test "$(cat "$out/upstream-stored.status")" -eq 0
grep -Fq "implicit interface" "$out/upstream-primal.stderr"
grep -Fq "implicit interface" "$out/upstream-stored.stderr"

# Contract test 2: fresh pinned Tapenade parser, tangent, and reverse output.
for mode in p d b; do
    case "$mode" in
        p) label=parser ;;
        d) label=forward ;;
        b) label=reverse ;;
    esac
    run_status "fresh-$label-generation" bash -c \
        "cd '$out/fresh/$label' && '$tapenade' '-$mode' -head top -head compute \
         -O . -o v508 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$label-generation.status")" -eq 0
    test -s "$out/fresh/$label/v508_${mode}.f90"
    test -s "$out/fresh/$label/v508_${mode}.msg"
    compile_source "fresh-$label" "$out/fresh/$label/v508_${mode}.f90" \
        "$out/fresh/$label-mod"
done
test "$(cat "$out/fresh-parser.status")" -eq 0
test "$(cat "$out/fresh-forward.status")" -eq 0
test "$(cat "$out/fresh-reverse.status")" -ne 0
grep -Fq "compute_b" "$out/fresh-reverse.stderr"

# Contract test 3: exact FortAD parser, forward, and reverse behavior.
run_status fortad-parser "$fortad" check --proc top \
    --output "$out/fortad/parser.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-parser.status")" -eq 0
test -s "$out/fortad/parser.f90"
compile_source fortad-parser-compile "$out/fortad/parser.f90" \
    "$out/fortad/parser-mod" -I"$out/exact/primal-mod"
test "$(cat "$out/fortad-parser-compile.status")" -ne 0
grep -Fq "Invalid character in name" "$out/fortad-parser-compile.stderr"

run_status fortad-forward "$fortad" --mode forward --indep r,s --dep top \
    --proc top --name v508_forward --module v508_forward_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-forward.status")" -eq 0
test -s "$out/fortad/forward.f90"
compile_source fortad-forward-compile "$out/fortad/forward.f90" \
    "$out/fortad/forward-mod" -I"$out/exact/primal-mod"
test "$(cat "$out/fortad-forward-compile.status")" -ne 0
grep -Fq "Invalid character in name" "$out/fortad-forward-compile.stderr"

run_status fortad-reverse "$fortad" --mode reverse --indep r,s --dep top \
    --proc top --name v508_reverse --module v508_reverse_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-reverse.status")" -ne 0
test ! -e "$out/fortad/reverse.f90"
grep -Fq "assignment to undeclared 'y'" "$out/fortad-reverse.stderr"

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90/REFERENCES/v508 external inout/global-state boundary\n'
    printf 'classification: expected-refusal-external-inout-global-state-and-codegen\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_points: top(r,s); compute(x,y)\n'
    printf 'tapenade_options: -head top -head compute; parser=-p tangent=-d reverse=-b\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_program_d=%s\n' \
        "$(cat "$out/upstream-primal.status")" "$(cat "$out/upstream-stored.status")"
    printf 'upstream_diagnostic: implicit-interface-warnings-for-external-compute-ftest-top\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-forward-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v508_p.f90 tangent=v508_d.f90 reverse=v508_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=expected-refusal-%s\n' \
        "$(cat "$out/fresh-parser.status")" "$(cat "$out/fresh-forward.status")" \
        "$(cat "$out/fresh-reverse.status")"
    printf 'fresh_reverse_diagnostic: undeclared-COMPUTE_B-interface\n'
    printf 'fortad_exact_parser: transform=%s generated=strict-compile-%s diagnostic="result() and blank declarations"\n' \
        "$(cat "$out/fortad-parser.status")" "$(cat "$out/fortad-parser-compile.status")"
    printf 'fortad_exact_forward: transform=%s generated=strict-compile-%s diagnostic="blank dependent arguments"\n' \
        "$(cat "$out/fortad-forward.status")" "$(cat "$out/fortad-forward-compile.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="assignment to undeclared y"\n' \
        "$(cat "$out/fortad-reverse.status")"
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-exact-external-inout-global-state-boundary\n'
    printf 'closure: no bounded port; changing the external-call shape or global state would define a different candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/m.mod \
        "$source_rel"/program.f90 "$source_rel"/program_d.f90 "$source_rel"/program_d.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && find . -type f \( -name '*.f90' -o -name '*.msg' \) -print0 | \
        sort -z | xargs -0 sha256sum)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
