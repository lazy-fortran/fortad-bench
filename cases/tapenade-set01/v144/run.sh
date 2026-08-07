#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
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

result="$case_dir/result.txt"
required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/todoF90/REFERENCES/v144"
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
test -x "$fortad"
test -x "$tapenade"

for source in program.f90 program_d.f90 program_d.msg program_b.f90 program_b.msg; do
    test -e "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-todof90-v144.XXXXXX)
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
    if "$fc" "${strict_flags[@]}" -I"$source_dir" -J"$out/mod/$label" \
        -c "$source" -o "$out/$label.o" >"$out/$label.stdout" \
        2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

mkdir -p "$out/mod/exact_program" "$out/mod/stored_tangent" \
    "$out/mod/stored_reverse" "$out/mod/fresh_parser" \
    "$out/mod/fresh_tangent" "$out/mod/fresh_reverse"
compile_strict exact_program "$source_dir/program.f90"
compile_strict stored_tangent "$source_dir/program_d.f90"
compile_strict stored_reverse "$source_dir/program_b.f90"
test "$(<"$out/exact_program.status")" -ne 0
test "$(<"$out/stored_tangent.status")" -ne 0
test "$(<"$out/stored_reverse.status")" -ne 0
grep -Fq "Explicit interface required for" "$out/exact_program.stderr"
grep -Fq "Rank mismatch in argument" "$out/exact_program.stderr"
grep -Fq "Legacy Extension: REAL array index" "$out/stored_tangent.stderr"
grep -Fq "Legacy Extension: REAL array index" "$out/stored_reverse.stderr"

generate_tapenade() {
    local label=$1
    local mode=$2
    local output_dir=$3
    local status
    if (cd "$output_dir" && "$tapenade" "$mode" -root head -O . -o v144 \
        "$source_dir/program.f90") >"$out/$label-generation.stdout" \
        2>"$out/$label-generation.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label-generation.status"
}

generate_tapenade parser -p "$out/tapenade/parser"
generate_tapenade forward -d "$out/tapenade/forward"
generate_tapenade reverse -b "$out/tapenade/reverse"
for label in parser forward reverse; do
    test "$(<"$out/$label-generation.status")" -eq 0
done
test -e "$out/tapenade/parser/v144_p.f90"
test -e "$out/tapenade/parser/v144_p.msg"
test -e "$out/tapenade/forward/v144_d.f90"
test -e "$out/tapenade/forward/v144_d.msg"
test -e "$out/tapenade/reverse/v144_b.f90"
test -e "$out/tapenade/reverse/v144_b.msg"

compile_strict fresh_parser "$out/tapenade/parser/v144_p.f90"
compile_strict fresh_tangent "$out/tapenade/forward/v144_d.f90"
compile_strict fresh_reverse "$out/tapenade/reverse/v144_b.f90"
for label in fresh_parser fresh_tangent fresh_reverse; do
    test "$(<"$out/$label.status")" -ne 0
done
grep -Fq "Explicit interface required for" "$out/fresh_parser.stderr"
grep -Fq "Rank mismatch in argument" "$out/fresh_parser.stderr"
grep -Fq "Explicit interface required for" "$out/fresh_tangent.stderr"
grep -Fq "Rank mismatch in argument" "$out/fresh_tangent.stderr"
grep -Fq "Rank mismatch in argument" "$out/fresh_reverse.stderr"

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

run_fortad parser check --proc head -o "$out/exact/parser.f90" \
    "$source_dir/program.f90"
run_fortad forward --mode forward --indep a,c --proc head \
    --name v144_forward --module v144_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_fortad reverse --mode reverse --indep a,c --dep resu --proc head \
    --name v144_reverse --module v144_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for label in parser forward reverse; do
    test "$(<"$out/fortad-$label.status")" -ne 0
    test ! -e "$out/exact/$label.f90"
    grep -Fq "fortad: unsupported expression at line 10" \
        "$out/fortad-$label.stderr"
done

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90/REFERENCES/v144 invalid implicit-interface boundary\n'
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
    printf 'upstream_entry_point: head(a,b,c,resu); helper F(t,u)\n'
    printf 'tapenade_options: parser=-p/-root head forward=-d/-root head reverse=-b/-root head\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_d.f90=%s program_b.f90=%s\n' \
        "$(<"$out/exact_program.status")" "$(<"$out/stored_tangent.status")" \
        "$(<"$out/stored_reverse.status")"
    printf 'upstream_diagnostics: program.f90=explicit-interface-array-result-and-rank-mismatch program_d.f90=legacy-real-array-index program_b.f90=legacy-real-array-index-and-rank-mismatch\n'
    printf 'upstream_stored_references: program_d.f90=present program_d.msg=present program_b.f90=present program_b.msg=present program_p.f90=missing\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(<"$out/parser-generation.status")" "$(<"$out/forward-generation.status")" \
        "$(<"$out/reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s\n' \
        "$(<"$out/fresh_parser.status")" "$(<"$out/fresh_tangent.status")" \
        "$(<"$out/fresh_reverse.status")"
    printf 'tapenade_fresh_messages: parser=v144_p.msg forward=v144_d.msg reverse=v144_b.msg (all present; empty)\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="fortad: unsupported expression at line 10"\n' \
        "$(<"$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="fortad: unsupported expression at line 10"\n' \
        "$(<"$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="fortad: unsupported expression at line 10"\n' \
        "$(<"$out/fortad-reverse.status")"
    printf 'independent_oracle: pass-strict-gfortran-diagnostics-and-pinned-source-checksums\n'
    printf 'port_result: not-applicable-invalid-upstream-source\n'
    printf 'closure: no bounded port or exact-source support claim; repairing the implicit interface or rank mismatch would change the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f90 program_d.f90 program_d.msg program_b.f90 program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum v144_p.f90 v144_p.msg)
    (cd "$out/tapenade/forward" && sha256sum v144_d.f90 v144_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum v144_b.f90 v144_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md run.sh test_contract.py)
} >"$result"
cat "$result"
