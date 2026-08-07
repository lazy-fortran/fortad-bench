#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v07 invalid-module boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >/dev/null
fi
test -x "$fortad"
test -x "$tapenade"

source_dir="$tapenade_repo/todoF90/REFERENCES/v07"
source="$source_dir/program.f90"
test -s "$source"

out=$(mktemp -d /var/tmp/fortad-bench-v07.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/exact"

strict_flags=(-std=f2018 -ffree-form -fsyntax-only -pedantic-errors -Wall -Wextra
    -Wimplicit-interface -cpp -I"$tapenade_repo" -I"$source_dir" -J"$out/mod")

compile_source() {
    local source_path=$1
    local label=$2
    local status
    set +e
    "$fc" "${strict_flags[@]}" "$source_path" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source "$source" upstream
test "$(cat "$out/upstream.status")" -ne 0
grep -Fq "foo" "$out/upstream.stderr"
grep -Fq "has no IMPLICIT type" "$out/upstream.stderr"

run_tapenade() {
    local label=$1
    local directory=$2
    local mode=$3
    local status
    set +e
    (cd "$directory" && "$tapenade" "$mode" -O . -o "v07_$label" "$source") \
        >"$out/tapenade-$label.stdout" 2>"$out/tapenade-$label.stderr"
    status=$?
    set -e
    printf '%s\n' "$status" >"$out/tapenade-$label.status"
}

run_tapenade parser "$out/tapenade/parser" -p
run_tapenade tangent "$out/tapenade/forward" -d
run_tapenade reverse "$out/tapenade/reverse" -b
for label in parser tangent reverse; do
    test "$(cat "$out/tapenade-$label.status")" -eq 0
done

parser_source="$out/tapenade/parser/v07_parser_p.f90"
parser_message="$out/tapenade/parser/v07_parser_p.msg"
tangent_message="$out/tapenade/forward/v07_tangent_d.msg"
reverse_message="$out/tapenade/reverse/v07_reverse_b.msg"
test -s "$parser_source"
test -s "$parser_message"
test -s "$tangent_message"
test -s "$reverse_message"
test ! -e "$out/tapenade/forward/v07_tangent_d.f90"
test ! -e "$out/tapenade/reverse/v07_reverse_b.f90"
grep -Fq "No implicit rule available" "$parser_message"
grep -Fq "No root unit to differentiate" "$tangent_message"
grep -Fq "No root unit to differentiate" "$reverse_message"

compile_source "$parser_source" fresh_parser
test "$(cat "$out/fresh_parser.status")" -ne 0
grep -Fq "foo" "$out/fresh_parser.stderr"
grep -Fq "has no IMPLICIT type" "$out/fresh_parser.stderr"

fortad_probe() {
    local label=$1
    local output=$2
    shift 2
    local status
    set +e
    "$fortad" "$@" --output "$output" "$source" \
        >"$out/exact/$label.stdout" 2>"$out/exact/$label.stderr"
    status=$?
    set -e
    printf '%s\n' "$status" >"$out/exact/$label.status"
    test "$status" -ne 0
    test ! -e "$output"
}

fortad_probe parser "$out/exact/parser.f90" check
fortad_probe forward "$out/exact/forward.f90" jvp foo --proc foo \
    --name v07_jvp --module v07_jvp_mod
fortad_probe reverse "$out/exact/reverse.f90" vjp foo --dep foo --proc foo \
    --name v07_vjp --module v07_vjp_mod
grep -Fq "fortad: no function or subroutine found in source" \
    "$out/exact/parser.stderr"
grep -Fq "fortad: no procedure named 'foo' in this source" \
    "$out/exact/forward.stderr"
grep -Fq "fortad: no procedure named 'foo' in this source" \
    "$out/exact/reverse.stderr"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90/REFERENCES/v07 invalid module boundary\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'fortad_worktree: clean-and-pinned\n'
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: none (MODULE TEST has no program/function/subroutine)\n'
    printf 'tapenade_options: parser=-p tangent=-d reverse=-b (no root; source has no top procedure)\n'
    printf 'upstream_exact_strict_compile: program.f90=%s\n' "$(cat "$out/upstream.status")"
    printf 'upstream_exact_diagnostic: gfortran=undeclared-public-foo-under-IMPLICIT-NONE\n'
    printf 'upstream_exact_diagnostic_text: '
    grep -F 'Error:' "$out/upstream.stderr" | sed 's/^[[:space:]]*//'
    printf 'stored_references: none\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-tangent.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_outputs: parser=v07_parser_p.f90 tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=v07_parser_p.msg tangent=v07_tangent_d.msg reverse=v07_reverse_b.msg\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_fresh_parser_diagnostic: undeclared-public-foo-under-IMPLICIT-NONE\n'
    printf 'tapenade_fresh_parser_diagnostic_text: '
    grep -F 'Error:' "$out/fresh_parser.stderr" | sed 's/^[[:space:]]*//'
    printf 'tapenade_fresh_tangent_reverse_diagnostic: no-top-procedure-and-undeclared-foo\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="fortad: no function or subroutine found in source"\n' \
        "$(cat "$out/exact/parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="fortad: no procedure named foo in this source"\n' \
        "$(cat "$out/exact/forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="fortad: no procedure named foo in this source"\n' \
        "$(cat "$out/exact/reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: reproducible strict compiler diagnostic and pinned source SHA-256; no numerical oracle for invalid source\n'
    printf 'port_result: not-applicable-no-standard-conforming-semantics-to-preserve\n'
    printf 'closure: no bounded port or exact-source support claim; adding foo or operator bodies would change the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f90)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum v07_parser_p.f90 v07_parser_p.msg)
    (cd "$out/tapenade/forward" && sha256sum v07_tangent_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum v07_reverse_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v07/manifest.toml \
        cases/tapenade-set01/v07/notes.md cases/tapenade-set01/v07/run.sh \
        cases/tapenade-set01/v07/test_contract.py)
} >"$result"

cat "$result"
