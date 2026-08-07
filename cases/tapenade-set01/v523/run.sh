#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set07/v523 empty-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad/.git; then
    fortad_repo=/mnt/storage/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=3a946d34d3caa7a75fb6f891139023650b4ce51a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set07/v523
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
test -f "$source_dir/program.f90"
test -f "$source_dir/program_p.msg"
test ! -e "$source_dir/program_p.f90"
test ! -e "$source_dir/program_d.f90"
test ! -e "$source_dir/program_b.f90"
test ! -s "$source_dir/program.f90"
test ! -s "$source_dir/program_p.msg"

out=$(mktemp -d /var/tmp/fortad-bench-v523.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

# Contract 1: exact source compiles; the only stored reference is empty metadata.
mkdir -p "$out/exact/mod"
run_status exact-source "$fc" "${strict_flags[@]}" -c "$source_dir/program.f90" \
    -J"$out/exact/mod" -o "$out/exact/source.o"
test "$(cat "$out/exact-source.status")" -eq 0
test ! -s "$out/exact-source.stdout"
test ! -s "$out/exact-source.stderr"
test ! -s "$source_dir/program_p.msg"

# Contract 2: fresh pinned Tapenade parser, tangent, and reverse probes.
for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p ;;
        forward) flag=-d; suffix=d ;;
        reverse) flag=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$flag' -O . -o v523 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -f "$out/fresh/$mode/v523_${suffix}.msg"
    test ! -e "$out/fresh/$mode/v523_${suffix}.f90"
done
test ! -s "$out/fresh/parser/v523_p.msg"
for message in "$out/fresh/forward/v523_d.msg" "$out/fresh/reverse/v523_b.msg"; do
    grep -Fq "No root unit to differentiate" "$message"
    grep -Fq "The code provided does not contain a top procedure" "$message"
done

# Contract 3: the repaired FortAD CLI refuses all three no-entry requests.
fortad_probe() {
    local label=$1
    shift
    run_status "fortad-$label" "$@"
    test "$(cat "$out/fortad-$label.status")" -ne 0
    test ! -e "$out/fortad-$label.f90"
    grep -Fqi "no function or subroutine found in source" \
        "$out/fortad-$label.stdout" "$out/fortad-$label.stderr"
}

fortad_probe parser "$fortad" check --output "$out/fortad-parser.f90" \
    "$source_dir/program.f90"
fortad_probe forward "$fortad" "$source_dir/program.f90" --mode forward \
    --indep p1 --output "$out/fortad-forward.f90"
fortad_probe reverse "$fortad" --mode reverse --indep p1 --dep p2 \
    --output "$out/fortad-reverse.f90" "$source_dir/program.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f90")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"
grep -Fqx "derivative_domain: empty-no-entry-point" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set07 v523\n'
    printf 'classification: expected-refusal-empty-source-no-entry-point\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: tracked-clean-and-pinned\n'
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'source_checkout: %s\n' "$tapenade_repo"
    printf 'upstream_entry_point: none (empty source)\n'
    printf 'selected_entry_points: none\n'
    printf 'tapenade_options: parser=-p forward=-d reverse=-b; no root\n'
    printf 'upstream_exact_strict_compile: program.f90=%s\n' \
        "$(cat "$out/exact-source.status")"
    printf 'stored_reference_compiler_behavior: program_p.msg=not-applicable-empty-message-only\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=none tangent=none reverse=none\n'
    printf 'tapenade_fresh_messages: parser=empty tangent=no-root reverse=no-root\n'
    printf 'tapenade_no_root_diagnostic: tangent-and-reverse-message-only-no-root-no-top-procedure\n'
    printf 'fortad_exact_parser: expected-refusal status=%s diagnostic="no function or subroutine found in source" output=none\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="no function or subroutine found in source" output=none\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="no function or subroutine found in source" output=none\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: empty source semantic inventory\n'
    printf '%s\n' "$oracle_output"
    printf 'port_result: not-applicable-empty-no-entry-point\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v523_p.msg)
    (cd "$out/fresh/forward" && sha256sum v523_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v523_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v523/manifest.toml \
        cases/tapenade-set01/v523/notes.md cases/tapenade-set01/v523/oracle.py \
        cases/tapenade-set01/v523/run.sh cases/tapenade-set01/v523/test_contract.py)
} >"$result"
cat "$result"
