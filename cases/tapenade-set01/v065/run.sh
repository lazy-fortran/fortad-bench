#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set02/v065 no-entry boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}

if test ! -e "$tapenade_repo/.git" && test -e "$root/.git"; then
    common_git_dir=$(git -C "$root" rev-parse --git-common-dir)
    common_root=$(cd "$(dirname "$common_git_dir")" && pwd)
    if test -e "$common_root/upstream/tapenade/.git"; then
        tapenade_repo="$common_root/upstream/tapenade"
    fi
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set02/v065
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"

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
for source in program.f program_p.f program_p.msg; do
    test -e "$source_dir/$source"
done
for absent in program_d.f program_d.msg program_b.f program_b.msg; do
    test ! -e "$source_dir/$absent"
done

out=$(mktemp -d /var/tmp/fortad-bench-v065.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/stored" "$out/fresh/parser" \
    "$out/fresh/forward" "$out/fresh/reverse" "$out/fortad"

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
fixed_flags=(-std=f2018 -ffixed-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)

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
    local form=$3
    local moddir=$4
    mkdir -p "$moddir"
    if test "$form" = free; then
        run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
            -J"$moddir" -c "$source" -o "$out/$label.o"
    else
        run_status "$label" "$fc" "${fixed_flags[@]}" -I"$source_dir" \
            -J"$moddir" -c "$source" -o "$out/$label.o"
    fi
}

compile_source exact_primal "$source_dir/program.f" free "$out/exact/mod"
compile_source stored_parser "$source_dir/program_p.f" fixed "$out/stored/mod"
test "$(cat "$out/exact_primal.status")" -eq 0
test "$(cat "$out/stored_parser.status")" -eq 0

run_tapenade() {
    local label=$1
    local mode=$2
    local directory=$3
    mkdir -p "$directory"
    run_status "tapenade-$label" bash -c \
        "cd '$directory' && '$tapenade' '$mode' -O . -o v065 '$source_dir/program.f'"
}

run_tapenade parser -p "$out/fresh/parser"
run_tapenade tangent -d "$out/fresh/forward"
run_tapenade reverse -b "$out/fresh/reverse"
for label in parser tangent reverse; do
    test "$(cat "$out/tapenade-$label.status")" -eq 0
done
test -s "$out/fresh/parser/v065_p.f"
test -e "$out/fresh/parser/v065_p.msg"
test -e "$out/fresh/forward/v065_d.msg"
test -e "$out/fresh/reverse/v065_b.msg"
test ! -e "$out/fresh/forward/v065_d.f"
test ! -e "$out/fresh/reverse/v065_b.f"
grep -Fq "No root unit to differentiate" "$out/tapenade-tangent.stdout"
grep -Fq "No root unit to differentiate" "$out/tapenade-reverse.stdout"
compile_source fresh_parser "$out/fresh/parser/v065_p.f" fixed "$out/fresh/parser/mod"
test "$(cat "$out/fresh_parser.status")" -eq 0

run_status fortad-parser "$fortad" check \
    --output "$out/fortad/parser.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --indep II \
    --name v065_forward --output "$out/fortad/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --indep II --dep JJ \
    --name v065_reverse --output "$out/fortad/reverse.f90" "$source_dir/program.f"
for label in parser forward reverse; do
    test "$(cat "$out/fortad-$label.status")" -eq 1
    test ! -e "$out/fortad/$label.f90"
    grep -Fq "fortad: no function or subroutine found in source" \
        "$out/fortad-$label.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set02/v065 BLOCKDATA no-entry boundary\n'
    printf 'classification: expected-refusal-no-entry-point-reference-only\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags_free: %s\n' "${strict_flags[*]}"
    printf 'strict_compiler_flags_fixed: %s\n' "${fixed_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: none (BLOCKDATA; no function or subroutine)\n'
    printf 'stored_references: program_p.f program_p.msg\n'
    printf 'missing_stored_references: program_d.f program_d.msg program_b.f program_b.msg\n'
    printf 'tapenade_options: parser=-p tangent=-d reverse=-b (no root)\n'
    printf 'upstream_exact_strict_compile: program.f=%s program_p.f=%s\n' \
        "$(cat "$out/exact_primal.status")" "$(cat "$out/stored_parser.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-tangent.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_sources: parser=v065_p.f tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=v065_p.msg tangent=v065_d.msg reverse=v065_b.msg\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_tangent_reverse_diagnostic: No root unit to differentiate\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="no function or subroutine found in source"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_semantic_oracle:\n'
    sed 's/^/  /' "$out/oracle.txt"
    printf 'port_result: not-claimed reason=no-callable-procedure-interface\n'
    printf 'closure: BLOCKDATA and parser-reference-only; no transformable entry point exists\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_p.f "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v065_p.f v065_p.msg)
    (cd "$out/fresh/forward" && sha256sum v065_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v065_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"

cat "$result"
