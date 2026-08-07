#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
if test -n "${FORTAD_REPO:-}"; then fortad_repo=$FORTAD_REPO
elif test -d "$root/../fortad"; then fortad_repo="$root/../fortad"
else fortad_repo=/mnt/storage/code/lazy-fortran/fortad; fi
if test -n "${TAPENADE_REPO:-}"; then tapenade_repo=$TAPENADE_REPO
elif test -d "$root/upstream/tapenade"; then tapenade_repo="$root/upstream/tapenade"
else tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade; fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=todoF90/REFERENCES/v412
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
result="$case_dir/result.txt"

test -e "$fortad_repo/.git"; test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
command -v "$fc" >/dev/null; command -v java >/dev/null
command -v python3 >/dev/null; test -x "$fortad"; test -x "$tapenade"
for source in Options program.f90 program_Rd.f90 program_Rd.msg; do test -s "$source_dir/$source"; done

out=$(mktemp -d /var/tmp/fortad-bench-todof90-v412.XXXXXX)
mkdir -p "$out/exact" "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/mod"
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp)

compile_strict() {
    local label=$1 source=$2 status
    mkdir -p "$out/mod/$label"
    if "$fc" "${strict_flags[@]}" -I"$source_dir" -J"$out/mod/$label" -c "$source" -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"; then status=0; else status=$?; fi
    printf '%s\n' "$status" >"$out/$label.status"
}

# Test 1: exact pinned upstream and stored reference strict behavior.
compile_strict exact_program "$source_dir/program.f90"
compile_strict stored_tangent "$source_dir/program_Rd.f90"
test "$(<"$out/exact_program.status")" -ne 0
test "$(<"$out/stored_tangent.status")" -ne 0
grep -Eq "Return type mismatch|Type mismatch in argument" "$out/exact_program.stderr"
grep -Fq "Symbol ‘f0’ at (1) has no IMPLICIT type" "$out/stored_tangent.stderr"

generate_tapenade() {
    local label=$1 mode=$2 output_dir=$3 status
    if (cd "$output_dir" && "$tapenade" "$mode" -root top -O . -o v412 "$source_dir/program.f90") >"$out/$label-generation.stdout" 2>"$out/$label-generation.stderr"; then status=0; else status=$?; fi
    printf '%s\n' "$status" >"$out/$label-generation.status"
}

# Test 2: fresh Tapenade generation plus strict compilation when applicable.
generate_tapenade parser -p "$out/tapenade/parser"
generate_tapenade forward -d "$out/tapenade/forward"
generate_tapenade reverse -b "$out/tapenade/reverse"
for file in "$out/tapenade/parser/v412_p.f90" "$out/tapenade/parser/v412_p.msg" "$out/tapenade/forward/v412_d.f90" "$out/tapenade/forward/v412_d.msg" "$out/tapenade/reverse/v412_b.f90" "$out/tapenade/reverse/v412_b.msg"; do test -s "$file"; done
for label in parser forward reverse; do test "$(<"$out/$label-generation.status")" -eq 0; done
compile_strict fresh_parser "$out/tapenade/parser/v412_p.f90"
compile_strict fresh_forward "$out/tapenade/forward/v412_d.f90"
compile_strict fresh_reverse "$out/tapenade/reverse/v412_b.f90"
for label in fresh_parser fresh_forward fresh_reverse; do
    test "$(<"$out/$label.status")" -ne 0
    grep -Fq "Type mismatch in argument" "$out/$label.stderr"
done

run_fortad() {
    local label=$1 status; shift
    if "$fortad" "$@" >"$out/fortad-$label.stdout" 2>"$out/fortad-$label.stderr"; then status=0; else status=$?; fi
    printf '%s\n' "$status" >"$out/fortad-$label.status"
}

# Test 3: exact FortAD parser/forward/reverse refusal behavior.
run_fortad parser check --proc top -o "$out/exact/parser.f90" "$source_dir/program.f90"
run_fortad forward --mode forward --indep x --proc top --name v412_forward --module v412_forward_mod --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_fortad reverse --mode reverse --indep x --dep y --proc top --name v412_reverse --module v412_reverse_mod --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for label in parser forward reverse; do
    test "$(<"$out/fortad-$label.status")" -ne 0
    test ! -e "$out/exact/$label.f90"
    grep -Fq "fortad: unsupported statement at line 56" "$out/fortad-$label.stderr"
done

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v412 mixed-kind and unsupported-statement boundary\n'
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
    printf 'upstream_entry_point: top(x,y); helpers f0-f7\n'
    printf 'tapenade_options: parser=-p/-root top forward=-d/-root top reverse=-b/-root top\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_Rd.f90=%s\n' "$(<"$out/exact_program.status")" "$(<"$out/stored_tangent.status")"
    printf 'upstream_diagnostics: program.f90=implicit-interface-return-type-and-real-kind-mismatch program_Rd.f90=undeclared-generated-function-results-and-mixed-kind-calls\n'
    printf 'upstream_stored_references: program_Rd.f90=present program_Rd.msg=present program_Rb.f90=missing program_Rb.msg=missing\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' "$(<"$out/parser-generation.status")" "$(<"$out/forward-generation.status")" "$(<"$out/reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v412_p.f90 forward=v412_d.f90 reverse=v412_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s\n' "$(<"$out/fresh_parser.status")" "$(<"$out/fresh_forward.status")" "$(<"$out/fresh_reverse.status")"
    printf 'tapenade_fresh_diagnostic: mixed-kind-call-Type-mismatch-in-argument\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="fortad: unsupported statement at line 56"\n' "$(<"$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="fortad: unsupported statement at line 56"\n' "$(<"$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="fortad: unsupported statement at line 56"\n' "$(<"$out/fortad-reverse.status")"
    printf 'independent_oracle: pass-strict-gfortran-and-pinned-source-checksums\n'
    printf 'port_result: not-applicable-invalid-upstream-source\n'
    printf 'closure: no bounded port or exact-source support claim; repairing mixed kinds, interfaces, or RETURN support would change the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum Options program.f90 program_Rd.f90 program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum v412_p.f90 v412_p.msg)
    (cd "$out/tapenade/forward" && sha256sum v412_d.f90 v412_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum v412_b.f90 v412_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md run.sh test_contract.py)
} >"$result"
cat "$result"
