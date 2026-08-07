#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v270 invalid-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test -z "${TAPENADE_REPO+x}" && test ! -e "$tapenade_repo/.git"; then
    common_git_dir=$(git -C "$root" rev-parse --git-common-dir)
    shared_root=$(cd "$(dirname "$common_git_dir")" && pwd)
    if test -e "$shared_root/upstream/tapenade/.git"; then
        tapenade_repo="$shared_root/upstream/tapenade"
    fi
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/todoF90/REFERENCES/v270"
out=$(mktemp -d /var/tmp/fortad-bench-v270.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade_repo/bin/tapenade"
test -x "$fortad_repo/build/fo/bin/fortad"
for source in program.f90 DIFFSIZES.f90 Options NoInlineABS README \
    program_d.f90 program_d.msg program_dv.f90 program_dv.msg; do
    test -s "$source_dir/$source"
done

mkdir -p "$out/upstream/mod" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/exact"

compile_source() {
    local source=$1 label=$2
    local status=0
    "$fc" "${strict_flags[@]}" -J"$out/upstream/mod" -I"$source_dir" \
        -I"$out/upstream/mod" -c "$source" -o "$out/$label.o" \
        >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source "$source_dir/DIFFSIZES.f90" diffsizes
compile_source "$source_dir/program.f90" upstream
compile_source "$source_dir/program_d.f90" stored_d
compile_source "$source_dir/program_dv.f90" stored_dv
test "$(cat "$out/diffsizes.status")" -eq 0
test "$(cat "$out/upstream.status")" -ne 0
test "$(cat "$out/stored_d.status")" -ne 0
test "$(cat "$out/stored_dv.status")" -ne 0

run_tapenade() {
    local mode=$1 output_dir=$2
    shift 2
    local status=0
    (cd "$tapenade_repo/todoF90" && "$tapenade_repo/bin/tapenade" "$@" \
        -O "$output_dir" -o v270 "$source_dir/program.f90") \
        >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr" || status=$?
    printf '%s\n' "$status" >"$out/tapenade-$mode.status"
}

run_tapenade parser "$out/fresh/parser" -p -nolib -ext REFERENCES/v270/NoInlineABS
run_tapenade tangent "$out/fresh/forward" -d -root solvereal -nolib \
    -ext REFERENCES/v270/NoInlineABS
run_tapenade reverse "$out/fresh/reverse" -b -root solvereal -nolib \
    -ext REFERENCES/v270/NoInlineABS
for mode in parser tangent reverse; do
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
done
test -s "$out/fresh/parser/v270_p.f90"
test -s "$out/fresh/forward/v270_d.f90"
test -s "$out/fresh/reverse/v270_b.f90"
compile_source "$out/fresh/parser/v270_p.f90" fresh_parser
compile_source "$out/fresh/forward/v270_d.f90" fresh_tangent
compile_source "$out/fresh/reverse/v270_b.f90" fresh_reverse
for mode in parser tangent reverse; do
    test "$(cat "$out/fresh_$(test "$mode" = tangent && echo tangent || echo "$mode").status")" -ne 0
done

fortad_exec() {
    local label=$1
    shift
    local status=0
    (cd "$fortad_repo" && fo exec --no-build fortad "$@") \
        >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

fortad_exec exact_parser check --proc solvereal \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
fortad_exec exact_forward --mode forward --proc solvereal --indep this,c \
    --name v270_jvp --module v270_forward --output "$out/exact/forward.f90" \
    "$source_dir/program.f90"
fortad_exec exact_reverse --mode reverse --proc solvereal --indep this,c \
    --dep this --name v270_vjp --module v270_reverse \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/exact_$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "fortad: unsupported allocation lifetime construct 'allocatable declaration/component' at line 6; active allocation state is not represented yet" \
        "$out/exact_$mode.stderr"
done

strict_diagnostic() {
    grep -F -m1 'Error: GNU Extension: Nonstandard type declaration REAL*8' "$1"
}
upstream_diagnostic=$(strict_diagnostic "$out/upstream.stderr")
stored_d_diagnostic=$(strict_diagnostic "$out/stored_d.stderr")
stored_dv_diagnostic=$(strict_diagnostic "$out/stored_dv.stderr")
fresh_parser_diagnostic=$(strict_diagnostic "$out/fresh_parser.stderr")
fresh_tangent_diagnostic=$(strict_diagnostic "$out/fresh_tangent.stderr")
fresh_reverse_diagnostic=$(strict_diagnostic "$out/fresh_reverse.stderr")
fortad_diagnostic="fortad: unsupported allocation lifetime construct 'allocatable declaration/component' at line 6; active allocation state is not represented yet"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES v270 invalid-source boundary\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: clean-and-pinned\n'
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'tapenade_worktree: clean-and-pinned\n'
    printf 'upstream_entry_point: simtest1.solvereal(this,c)\n'
    printf 'upstream_exact_strict_compile: program=%s diffsizes=%s\n' \
        "$(cat "$out/upstream.status")" "$(cat "$out/diffsizes.status")"
    printf 'upstream_exact_diagnostic: %s\n' "$upstream_diagnostic"
    printf 'stored_references: program_d.f90 program_dv.f90 plus messages and DIFFSIZES.f90\n'
    printf 'stored_strict_compile: program_d=%s program_dv=%s\n' \
        "$(cat "$out/stored_d.status")" "$(cat "$out/stored_dv.status")"
    printf 'stored_program_d_diagnostic: %s\n' "$stored_d_diagnostic"
    printf 'stored_program_dv_diagnostic: %s\n' "$stored_dv_diagnostic"
    printf 'tapenade_options: parser=-p tangent=-d/-root solvereal reverse=-b/-root solvereal -nolib -ext REFERENCES/v270/NoInlineABS\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-tangent.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_outputs: parser=v270_p.f90 tangent=v270_d.f90 reverse=v270_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" \
        "$(cat "$out/fresh_tangent.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'tapenade_fresh_parser_diagnostic: %s\n' "$fresh_parser_diagnostic"
    printf 'tapenade_fresh_tangent_diagnostic: %s\n' "$fresh_tangent_diagnostic"
    printf 'tapenade_fresh_reverse_diagnostic: %s\n' "$fresh_reverse_diagnostic"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/exact_parser.status")" "$fortad_diagnostic"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/exact_forward.status")" "$fortad_diagnostic"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/exact_reverse.status")" "$fortad_diagnostic"
    printf 'independent_oracle: reproducible strict compiler diagnostic and pinned source SHA-256; no numerical oracle for invalid source\n'
    printf 'port_result: not-applicable-no-standard-conforming-semantics-to-preserve\n'
    printf 'closure: no bounded port or exact-source support claim\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum DIFFSIZES.f90 NoInlineABS Options README \
        program.f90 program_d.f90 program_d.msg program_dv.f90 program_dv.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v270/manifest.toml \
        cases/tapenade-set01/v270/notes.md cases/tapenade-set01/v270/run.sh \
        cases/tapenade-set01/v270/test_contract.py)
} >"$result"
cat "$result"
