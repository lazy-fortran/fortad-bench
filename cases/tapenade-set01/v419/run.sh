#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v419 boundaries.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade}
if test ! -e "$fortad_repo/.git" && test -e /home/ert/code/lazy-fortran/fortad/.git; then
    fortad_repo=/home/ert/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=todoF90/REFERENCES/v419
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v419.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
test -x "$fortad"
test -x "$tapenade"
for source in Options mma.mod mmb.mod program.f90 program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done
test -s "$tapenade_repo/nonRegressions/DIFFSIZES.f90"

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact-mod" "$out/stored-mod" "$out/tapenade" "$out/exact"

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
        -I"$tapenade_repo/nonRegressions" -J"$moddir" -c "$source" \
        -o "$out/$label.o"
}

# Contract test 1: exact primal and stored derivative behavior.
compile_source stored-diffsizes "$tapenade_repo/nonRegressions/DIFFSIZES.f90" \
    "$out/stored-mod"
compile_source upstream-primal "$source_dir/program.f90" "$out/exact-mod"
compile_source stored-program-Rd "$source_dir/program_Rd.f90" "$out/stored-mod"
test "$(cat "$out/stored-diffsizes.status")" -eq 0
test "$(cat "$out/upstream-primal.status")" -ne 0
test "$(cat "$out/stored-program-Rd.status")" -ne 0
grep -Fq "assumed size array" "$out/upstream-primal.stderr"
grep -Fq "nonderived-type variable" \
    "$out/stored-program-Rd.stderr"
grep -Fq "isize1ofdrfaa" "$out/stored-program-Rd.stderr"

# Contract test 2: fresh parser, tangent, and reverse generation plus compile.
for mode in p d b; do
    mkdir -p "$out/tapenade/$mode"
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/tapenade/$mode' && '$tapenade' '-$mode' -root ROOT \
         -context -association byaddress -O . -o v419 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/tapenade/$mode/v419_${mode}.f90"
    test -s "$out/tapenade/$mode/v419_${mode}.msg"
    if test "$mode" != p; then
        compile_source "fresh-$mode-diffsizes" \
            "$tapenade_repo/nonRegressions/DIFFSIZES.f90" "$out/fresh-$mode-mod"
        test "$(cat "$out/fresh-$mode-diffsizes.status")" -eq 0
    fi
    compile_source "fresh-$mode-compile" "$out/tapenade/$mode/v419_${mode}.f90" \
        "$out/fresh-$mode-mod"
    test "$(cat "$out/fresh-$mode-compile.status")" -ne 0
done
grep -Fq "assumed size array" "$out/fresh-p-compile.stderr"
grep -Fq "isize1ofdrfaa" "$out/fresh-d-compile.stderr"
grep -Fq "INTEGER*4" "$out/fresh-b-compile.stderr"

# Contract test 3: exact FortAD parser/forward/reverse behavior.
run_status fortad-parser "$fortad" check --proc ROOT \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --indep X --proc ROOT \
    --name v419_forward --module v419_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --indep X --dep zz \
    --proc ROOT --name v419_reverse --module v419_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component'" \
        "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v419 context-association boundary\n'
    printf 'classification: expected-refusal-invalid-upstream-and-unsupported-allocatable-context\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: ROOT(X); program MAIN\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_program_Rd=%s\n' \
        "$(cat "$out/upstream-primal.status")" "$(cat "$out/stored-program-Rd.status")"
    printf 'upstream_exact_diagnostic: primal=assumed-size-SUM; stored=malformed-percent-and-context-size-references\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-p-generation.status")" \
        "$(cat "$out/fresh-d-generation.status")" "$(cat "$out/fresh-b-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-p-compile.status")" \
        "$(cat "$out/fresh-d-compile.status")" "$(cat "$out/fresh-b-compile.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="allocatable declaration/component"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="allocatable declaration/component"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="allocatable declaration/component"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: numeric initialized-prefix sums plus undefined-read and assumed-size semantic checks\n'
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-undefined-state-and-invalid-assumed-size-sum\n'
    printf 'closure: no bounded port; repairing allocation state or dummy bounds changes the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options \
        "$source_rel"/mma.mod "$source_rel"/mmb.mod "$source_rel"/program.f90 \
        "$source_rel"/program_Rd.f90 "$source_rel"/program_Rd.msg \
        nonRegressions/DIFFSIZES.f90)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade" && sha256sum p/v419_p.f90 p/v419_p.msg \
        d/v419_d.f90 d/v419_d.msg b/v419_b.f90 b/v419_b.msg)
} >"$result"
cat "$result"
