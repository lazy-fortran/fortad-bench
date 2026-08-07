#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v417 boundaries.
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
source_rel=todoF90/REFERENCES/v417
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v417.XXXXXX)
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
for source in Options program.f90 program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact-mod" "$out/exact" "$out/tapenade/p" \
    "$out/tapenade/d" "$out/tapenade/b" "$out/fresh-p-mod" \
    "$out/fresh-d-mod" "$out/fresh-b-mod"

run_status() {
    local label=$1
    shift
    local status
    if "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source() {
    local label=$1
    local source=$2
    local moddir=$3
    mkdir -p "$moddir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

# Contract test 1: exact primal and stored reference behavior.
compile_source upstream_primal "$source_dir/program.f90" "$out/exact-mod"
compile_source stored_program_Rd "$source_dir/program_Rd.f90" "$out/exact-mod"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/stored_program_Rd.status")" -eq 0

# Contract test 2: fresh parser, tangent, and reverse generation plus compile.
for mode in p d b; do
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/tapenade/$mode' && '$tapenade' -association byaddress '-$mode' \
         -root calc_force -O . -o v417 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/tapenade/$mode/v417_${mode}.f90"
    test -s "$out/tapenade/$mode/v417_${mode}.msg"
    compile_source "fresh-$mode-compile" \
        "$out/tapenade/$mode/v417_${mode}.f90" "$out/fresh-$mode-mod"
    test "$(cat "$out/fresh-$mode-compile.status")" -eq 0
done

# Contract test 3: exact FortAD parser, forward, and reverse behavior.
run_status fortad-parser "$fortad" check --proc calc_force \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward \
    --indep geom,prop,obj,acc --proc calc_force --name v417_forward \
    --module v417_forward_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse \
    --indep geom,prop,acc --dep obj --proc calc_force --name v417_reverse \
    --module v417_reverse_mod --output "$out/exact/reverse.f90" \
    "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component'" \
        "$out/fortad-$mode.stderr"
    grep -Fq "line 17" "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v417 allocatable-component boundary\n'
    printf 'classification: expected-refusal-unsupported-allocatable\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: calc_force(geom,prop,obj,acc)\n'
    printf 'tapenade_options: -association byaddress; parser=-p/-root calc_force forward=-d/-root calc_force reverse=-b/-root calc_force\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_program_Rd=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/stored_program_Rd.status")"
    printf 'stored_program_Rd_message: %s\n' "$(tr '\n' ';' < "$source_dir/program_Rd.msg")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-p-generation.status")" \
        "$(cat "$out/fresh-d-generation.status")" \
        "$(cat "$out/fresh-b-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-p-compile.status")" \
        "$(cat "$out/fresh-d-compile.status")" \
        "$(cat "$out/fresh-b-compile.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none line=17 diagnostic="allocatable declaration/component"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none line=17 diagnostic="allocatable declaration/component"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none line=17 diagnostic="allocatable declaration/component"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-exact-allocatable-component-refusal\n'
    printf 'closure: no bounded port; replacing allocatable components would change the exact candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options \
        "$source_rel"/program.f90 "$source_rel"/program_Rd.f90 \
        "$source_rel"/program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade" && sha256sum p/v417_p.f90 p/v417_p.msg \
        d/v417_d.f90 d/v417_d.msg b/v417_b.f90 b/v417_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
