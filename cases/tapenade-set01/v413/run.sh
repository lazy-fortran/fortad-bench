#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"

if test -n "${FORTAD_REPO:-}"; then
    fortad_repo=$FORTAD_REPO
elif test -d "$root/../fortad"; then
    fortad_repo="$root/../fortad"
else
    fortad_repo=/mnt/storage/code/lazy-fortran/fortad
fi
if test -n "${TAPENADE_REPO:-}"; then
    tapenade_repo=$TAPENADE_REPO
elif test -d "$root/upstream/tapenade"; then
    tapenade_repo="$root/upstream/tapenade"
else
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
python=${PYTHON:-python3}
source_dir="$tapenade_repo/todoF90/REFERENCES/v413"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v413.XXXXXX)
trap 'rm -rf "$out"' EXIT

test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v "$python" >/dev/null
test -x "$fortad"
test -x "$tapenade"
for source in Options program.f90 program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done

mkdir -p "$out/upstream" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/exact"
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)

compile_strict() {
    local label=$1
    local source=$2
    local moddir=$3
    local status=0
    mkdir -p "$moddir"
    if "$fc" "${strict_flags[@]}" -I"$source_dir" -J"$moddir" \
        -c "$source" -o "$out/$label.o" >"$out/$label.stdout" \
        2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_strict upstream_program "$source_dir/program.f90" \
    "$out/upstream/program-mod"
compile_strict upstream_stored_forward "$source_dir/program_Rd.f90" \
    "$out/upstream/stored-forward-mod"
test "$(cat "$out/upstream_program.status")" -eq 0
test "$(cat "$out/upstream_stored_forward.status")" -eq 0
grep -Fq "is used uninitialized" "$out/upstream_program.stderr"
grep -Fq "is used uninitialized" "$out/upstream_stored_forward.stderr"
grep -Fq "variable mt is used before initialized" "$source_dir/program_Rd.msg"

generate_tapenade() {
    local label=$1
    local mode=$2
    local status=0
    if (cd "$out/fresh/$label" && "$tapenade" "$mode" -root f4 \
        -O . -o v413 "$source_dir/program.f90") \
        >"$out/tapenade-$label.stdout" 2>"$out/tapenade-$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/tapenade-$label-generation.status"
}

generate_tapenade parser -p
generate_tapenade forward -d
generate_tapenade reverse -b
test "$(cat "$out/tapenade-parser-generation.status")" -eq 0
test "$(cat "$out/tapenade-forward-generation.status")" -eq 0
test "$(cat "$out/tapenade-reverse-generation.status")" -eq 0
for file in v413_p.f90 v413_p.msg; do test -s "$out/fresh/parser/$file"; done
for file in v413_d.f90 v413_d.msg; do test -s "$out/fresh/forward/$file"; done
for file in v413_b.f90 v413_b.msg; do test -s "$out/fresh/reverse/$file"; done
for mode in parser forward reverse; do
    case "$mode" in
        parser) suffix=p ;;
        forward) suffix=d ;;
        reverse) suffix=b ;;
    esac
    compile_strict "fresh_$mode" "$out/fresh/$mode/v413_${suffix}.f90" \
        "$out/fresh/$mode/mod"
    test "$(cat "$out/fresh_$mode.status")" -eq 0
    grep -Fq "is used uninitialized" "$out/fresh_$mode.stderr"
    grep -Fq "variable mt is used before initialized" \
        "$out/fresh/$mode/v413_${suffix}.msg"
done

run_fortad() {
    local label=$1
    shift
    local status=0
    if "$fortad" "$@" >"$out/fortad-$label.stdout" \
        2>"$out/fortad-$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/fortad-$label.status"
}

run_fortad parser check --proc f4 --output "$out/exact/parser.f90" \
    "$source_dir/program.f90"
run_fortad forward --mode forward --proc f4 --indep hr --name f4_d \
    --module v413_forward_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f90"
run_fortad reverse --mode reverse --proc f4 --indep hr --dep f4 --name f4_b \
    --module v413_reverse_mod --output "$out/exact/reverse.f90" \
    "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "unsupported statement at line 6" "$out/fortad-$mode.stderr"
done

"$python" "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass undefined-mt-propagates-through-exponent-ss-and-f4" \
    "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90/REFERENCES/v413 undefined local-state boundary\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: f4(t,ss,hr)\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_Rd.f90=%s\n' \
        "$(cat "$out/upstream_program.status")" \
        "$(cat "$out/upstream_stored_forward.status")"
    printf 'upstream_diagnostic: local mt used uninitialized; stored message=DF03 variable mt is used before initialized\n'
    printf 'stored_references: program_Rd.f90=present program_Rd.msg=present program_Rb.f90=missing program_Rb.msg=missing\n'
    printf 'tapenade_options: parser=-p/-root f4 forward=-d/-root f4 reverse=-b/-root f4; upstream Options recorded\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v413_p.f90 tangent=v413_d.f90 reverse=v413_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" \
        "$(cat "$out/fresh_forward.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="unsupported statement at line 6"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="unsupported statement at line 6"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="unsupported statement at line 6"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: %s\n' "$(cat "$out/oracle.txt")"
    printf 'port_result: not-applicable-undefined-local-mt\n'
    printf 'closure: no bounded port; assigning or exposing mt would change the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum Options program.f90 program_Rd.f90 program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/fresh/parser/v413_p.f90" "$out/fresh/parser/v413_p.msg" \
        "$out/fresh/forward/v413_d.f90" "$out/fresh/forward/v413_d.msg" \
        "$out/fresh/reverse/v413_b.f90" "$out/fresh/reverse/v413_b.msg"
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
