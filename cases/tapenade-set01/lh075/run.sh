#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh075 invalid fixed-form boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
if test -z "${TAPENADE_REPO+x}" && test ! -e "$tapenade_repo/.git"; then
    common_git_dir=$(git -C "$root" rev-parse --git-common-dir)
    shared_root=$(cd "$(dirname "$common_git_dir")" && pwd)
    if test -e "$shared_root/upstream/tapenade/.git"; then
        tapenade_repo="$shared_root/upstream/tapenade"
    fi
fi
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -ffixed-form -fsyntax-only -pedantic-errors -Wall -Wextra
    -Wimplicit-interface -cpp -I. -InonRegressions/set01/lh075)

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
fortad_worktree=clean

source_dir="$tapenade_repo/nonRegressions/set01/lh075"
for source in program.f program_p.f; do
    test -s "$source_dir/$source"
done
for reference in program_b.msg program_d.msg program_dv.msg program_p.msg; do
    test -s "$source_dir/$reference"
done

out=$(mktemp -d /var/tmp/fortad-bench-lh075.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/exact"

compile_source() {
    local source=$1
    local label=$2
    set +e
    (cd "$tapenade_repo" && "$fc" "${strict_flags[@]}" -J"$out/mod" "$source") \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source "$source_dir/program.f" upstream_program
compile_source "$source_dir/program_p.f" upstream_program_p
for label in upstream_program upstream_program_p; do
    test "$(cat "$out/$label.status")" -ne 0
    grep -Fq "Unexpected use of subroutine name" "$out/$label.stderr"
done

if test ! -x "$tapenade_repo/bin/tapenade" || \
        test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

run_tapenade() {
    local mode=$1
    local directory=$2
    shift 2
    set +e
    (cd "$directory" && "$tapenade" "$@" -O . -o lh075 \
        "$source_dir/program.f") >"$out/tapenade-$mode.stdout" \
        2>"$out/tapenade-$mode.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/tapenade-$mode.status"
}

run_tapenade parser "$out/tapenade/parser" -p
run_tapenade tangent "$out/tapenade/forward" -d -root phi
run_tapenade reverse "$out/tapenade/reverse" -b -root phi
for mode in parser tangent reverse; do
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
done

parser_source="$out/tapenade/parser/lh075_p.f"
tangent_source="$out/tapenade/forward/lh075_d.f"
reverse_source="$out/tapenade/reverse/lh075_b.f"
test -s "$parser_source"
test -s "$out/tapenade/parser/lh075_p.msg"
test -s "$out/tapenade/forward/lh075_d.msg"
test -s "$out/tapenade/reverse/lh075_b.msg"
test ! -e "$tangent_source"
test ! -e "$reverse_source"

compile_source "$parser_source" fresh_parser
test "$(cat "$out/fresh_parser.status")" -ne 0
grep -Fq "Unexpected use of subroutine name" "$out/fresh_parser.stderr"

fortad_probe() {
    local mode=$1
    local output=$2
    local log=$3
    local status
    set +e
    (cd "$fortad_repo" && fo exec --no-build fortad --mode "$mode" \
        --indep s1 --dep PHIS --proc phi --name "lh075_exact_$mode" \
        --module "lh075_exact_${mode}_mod" --output "$output" \
        "$source_dir/program.f") >"$log" 2>&1
    status=$?
    set -e
    printf '%s\n' "$status" >"${log%.log}.status"
    test "$status" -ne 0
    grep -Fq "fortad: unsupported statement at line 3" "$log"
    test ! -e "$output"
}

fortad_probe forward "$out/exact/forward.f90" "$out/exact/forward.log"
fortad_probe reverse "$out/exact/reverse.f90" "$out/exact/reverse.log"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh075 invalid fixed-form boundary\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s -J<scratch>\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: phi(PHIS,s1)\n'
    printf 'upstream_exact_strict_compile: program.f=%s program_p.f=%s\n' \
        "$(cat "$out/upstream_program.status")" "$(cat "$out/upstream_program_p.status")"
    printf 'upstream_exact_diagnostics:\n'
    for log in "$out/upstream_program.stderr" "$out/upstream_program_p.stderr"; do
        printf '%s:\n' "${log##*/}"
        grep -F 'Error:' "$log" || true
    done
    printf 'stored_references: program_p.f plus program_b.msg program_d.msg program_dv.msg program_p.msg\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-tangent.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_outputs: parser=lh075_p.f tangent=none reverse=none\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable-no-source reverse=not-applicable-no-source\n' \
        "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_fresh_parser_diagnostic:\n'
    grep -F 'Error:' "$out/fresh_parser.stderr" || true
    printf 'tapenade_fresh_message_diagnostics:\n'
    for message in "$out/tapenade/parser/lh075_p.msg" \
        "$out/tapenade/forward/lh075_d.msg" "$out/tapenade/reverse/lh075_b.msg"; do
        printf '%s:\n' "${message##*/}"
        cat "$message"
    done
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="fortad: unsupported statement at line 3"\n' \
        "$(cat "$out/exact/forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="fortad: unsupported statement at line 3"\n' \
        "$(cat "$out/exact/reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: source-boundary and SHA-256 contract; no bounded numerical oracle because the exact call is invalid\n'
    printf 'port_result: not-applicable-no-standard-conforming-semantics-to-preserve\n'
    printf 'closure: no port and no exact-source support claim; repairing PHI as a function would invent candidate semantics\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_b.msg program_d.msg program_dv.msg program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh075_p.f lh075_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh075_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh075_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh075/manifest.toml \
        cases/tapenade-set01/lh075/notes.md cases/tapenade-set01/lh075/run.sh \
        cases/tapenade-set01/lh075/test_contract.py)
} >"$result"

cat "$result"
