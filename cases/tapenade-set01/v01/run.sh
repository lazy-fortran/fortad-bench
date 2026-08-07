#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
result="$case_dir/result.txt"
required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/todoF90/REFERENCES/v01"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"

test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null

for source in program.f90 program_d.f90 program_d.msg flincom.mod; do
    test -s "$source_dir/$source"
done

if test ! -x "$fortad"; then
    command -v fo >/dev/null
    (cd "$fortad_repo" && fo build) >"/var/tmp/fortad-bench-v01-fortad-build.log" 2>&1
fi
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"/var/tmp/fortad-bench-v01-tapenade-build.log" 2>&1
fi
test -x "$fortad"
test -x "$tapenade"

out=$(mktemp -d /var/tmp/fortad-bench-todof90-v01.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/mod"

strict_flags=(
    -std=f2018
    -ffree-form
    -ffree-line-length-none
    -pedantic-errors
    -Wall
    -Wextra
    -Wimplicit-interface
    -cpp
)

compile_strict() {
    local label=$1
    local source=$2
    local status
    mkdir -p "$out/mod/$label"
    if "$fc" "${strict_flags[@]}" -I"$source_dir" -J"$out/mod/$label" \
        -c "$source" -o "$out/$label.o" >"$out/$label.stdout" \
        2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

generate_tapenade() {
    local label=$1
    local mode=$2
    local output_dir=$3
    local status
    if (cd "$output_dir" && "$tapenade" "$mode" -root flinopen_work -O . \
        -o v01 "$source_dir/program.f90") >"$out/$label-generation.stdout" \
        2>"$out/$label-generation.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label-generation.status"
}

run_fortad() {
    local label=$1
    shift
    local status
    if "$fortad" "$@" >"$out/fortad-$label.stdout" \
        2>"$out/fortad-$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/fortad-$label.status"
}

compile_strict exact_program "$source_dir/program.f90"
compile_strict stored_tangent "$source_dir/program_d.f90"
test "$(<"$out/exact_program.status")" -eq 0
test "$(<"$out/stored_tangent.status")" -eq 0

generate_tapenade parser -p "$out/tapenade/parser"
generate_tapenade forward -d "$out/tapenade/forward"
generate_tapenade reverse -b "$out/tapenade/reverse"
test "$(<"$out/parser-generation.status")" -eq 0
test "$(<"$out/forward-generation.status")" -eq 0
test "$(<"$out/reverse-generation.status")" -eq 0
test -s "$out/tapenade/parser/v01_p.f90"
test -s "$out/tapenade/parser/v01_p.msg"
test -s "$out/tapenade/forward/v01_d.f90"
test -s "$out/tapenade/forward/v01_d.msg"
test -s "$out/tapenade/reverse/v01_b.f90"
test -s "$out/tapenade/reverse/v01_b.msg"

compile_strict fresh_parser "$out/tapenade/parser/v01_p.f90"
compile_strict fresh_tangent "$out/tapenade/forward/v01_d.f90"
compile_strict fresh_reverse "$out/tapenade/reverse/v01_b.f90"
test "$(<"$out/fresh_parser.status")" -eq 0
test "$(<"$out/fresh_tangent.status")" -eq 0
test "$(<"$out/fresh_reverse.status")" -eq 0

indep=filename,iideb,iilen,jjdeb,jjlen,do_test,iim,jjm,llm,lon,lat,lev,ttm,date0,dt,fid_out
run_fortad parser check --proc flinopen_work -o "$out/exact/parser.f90" \
    "$source_dir/program.f90"
run_fortad forward --mode forward --indep "$indep" --proc flinopen_work \
    --name v01_forward --module v01_forward_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f90"
run_fortad reverse --mode reverse --indep "$indep" --dep itaus \
    --proc flinopen_work --name v01_reverse --module v01_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for label in parser forward reverse; do
    test "$(<"$out/fortad-$label.status")" -ne 0
    test ! -e "$out/exact/$label.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component' at line 9" \
        "$out/fortad-$label.stderr"
done

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90/REFERENCES/v01\n'
    printf 'classification: expected-refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_exact_strict_compile: program.f90=%s program_d.f90=%s\n' \
        "$(<"$out/exact_program.status")" "$(<"$out/stored_tangent.status")"
    printf 'upstream_stored_references: program_d.f90=present program_d.msg=present program_p.f90=missing program_b.f90=missing program_dv.f90=missing\n'
    printf 'upstream_diagnostics: exact-and-stored=implicit-interface-warnings-only\n'
    printf 'tapenade_options: parser=-p/-root flinopen_work forward=-d/-root flinopen_work reverse=-b/-root flinopen_work\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(test "$(<"$out/parser-generation.status")" -eq 0 && echo pass)" \
        "$(test "$(<"$out/forward-generation.status")" -eq 0 && echo pass)" \
        "$(test "$(<"$out/reverse-generation.status")" -eq 0 && echo pass)"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s\n' \
        "$(<"$out/fresh_parser.status")" "$(<"$out/fresh_tangent.status")" \
        "$(<"$out/fresh_reverse.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocatable declaration/component at line 9"\n' \
        "$(<"$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocatable declaration/component at line 9"\n' \
        "$(<"$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocatable declaration/component at line 9"\n' \
        "$(<"$out/fortad-reverse.status")"
    printf 'bounded_port: not-claimed reason=module-state-and-external-callback-specialization-would-change-the-case\n'
    printf 'oracle_status: pass strict-compiler-and-reproducible-FortAD-diagnostic\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        todoF90/REFERENCES/v01/program.f90 \
        todoF90/REFERENCES/v01/program_d.f90 \
        todoF90/REFERENCES/v01/program_d.msg \
        todoF90/REFERENCES/v01/flincom.mod)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum v01_p.f90 v01_p.msg)
    (cd "$out/tapenade/forward" && sha256sum v01_d.f90 v01_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum v01_b.f90 v01_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md run.sh test_contract.py)
} >"$result"
cat "$result"
