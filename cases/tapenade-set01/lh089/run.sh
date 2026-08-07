#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=7adc75030db3fa4422339d82d2725ae29ee13dac
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/nonRegressions/set01/lh089"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh089.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git" && test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad" && test -x "$tapenade"
for source in program.f program_d.f program_d.msg Options PUSHPOPGeneralLib; do test -s "$source_dir/$source"; done

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface)
run_status() {
    local label=$1; shift; local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

mkdir -p "$out/mod" "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" "$out/exact"
run_status exact-strict "$fc" "${strict[@]}" -c "$source_dir/program.f" -o "$out/exact-strict.o"
test "$(cat "$out/exact-strict.status")" -ne 0; grep -Fqi REAL*8 "$out/exact-strict.stderr"
run_status stored-strict "$fc" "${strict[@]}" -c "$source_dir/program_d.f" -o "$out/stored-strict.o"
test "$(cat "$out/stored-strict.status")" -ne 0; grep -Fqi REAL*8 "$out/stored-strict.stderr"
run_status exact-legacy "$fc" "${legacy[@]}" -c "$source_dir/program.f" -o "$out/exact-legacy.o"
test "$(cat "$out/exact-legacy.status")" -eq 0
run_status stored-legacy "$fc" "${legacy[@]}" -c "$source_dir/program_d.f" -o "$out/stored-legacy.o"
test "$(cat "$out/stored-legacy.status")" -eq 0

for mode in parser forward reverse; do
    case "$mode" in parser) tap_mode=-p; suffix=p;; forward) tap_mode=-d; suffix=d;; reverse) tap_mode=-b; suffix=b;; esac
    run_status "tapenade-$mode-generation" bash -c "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -root pushpop -ext '$source_dir/PUSHPOPGeneralLib' -O . -o lh089 '$source_dir/program.f'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/lh089_${suffix}.f" && test -e "$out/fresh/$mode/lh089_${suffix}.msg"
    run_status "fresh-$mode-legacy" "$fc" "${legacy[@]}" -c "$out/fresh/$mode/lh089_${suffix}.f" -o "$out/fresh-$mode-legacy.o"
    test "$(cat "$out/fresh-$mode-legacy.status")" -eq 0
    run_status "fresh-$mode-strict" "$fc" "${strict[@]}" -c "$out/fresh/$mode/lh089_${suffix}.f" -o "$out/fresh-$mode-strict.o"
    test "$(cat "$out/fresh-$mode-strict.status")" -ne 0; grep -Fqi REAL*8 "$out/fresh-$mode-strict.stderr"
done

run_status fortad-check "$fortad" check --proc pushpop --output "$out/exact/checked.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-check.status")" -eq 0; test -s "$out/exact/checked.f90"
! grep -Fqi REAL*8 "$out/exact/checked.f90"
run_status fortad-forward "$fortad" --mode forward --proc pushpop --indep a,b --output "$out/exact/forward.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-forward.status")" -ne 0
grep -Fq "fortad: independent 'a' is not declared in pushpop" "$out/fortad-forward.stderr"
test ! -e "$out/exact/forward.f90"
run_status fortad-reverse "$fortad" --mode reverse --proc pushpop --indep a,b --dep a --output "$out/exact/reverse.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-reverse.status")" -ne 0
grep -Fq "fortad: dependent 'a' is not declared in pushpop" "$out/fortad-reverse.stderr"
test ! -e "$out/exact/reverse.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"
{
    printf 'case: Tapenade nonRegressions/set01/lh089\n'
    printf 'classification: unsupported-legacy-real-star-8-fortad-declaration-resolution\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: pushpop(a,b)\n'
    printf 'strict_compile: exact=%s stored=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' "$(cat "$out/exact-strict.status")" "$(cat "$out/stored-strict.status")" "$(cat "$out/fresh-parser-strict.status")" "$(cat "$out/fresh-forward-strict.status")" "$(cat "$out/fresh-reverse-strict.status")"
    printf 'legacy_compile: exact=%s stored=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' "$(cat "$out/exact-legacy.status")" "$(cat "$out/stored-legacy.status")" "$(cat "$out/fresh-parser-legacy.status")" "$(cat "$out/fresh-forward-legacy.status")" "$(cat "$out/fresh-reverse-legacy.status")"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' "$(cat "$out/tapenade-parser-generation.status")" "$(cat "$out/tapenade-forward-generation.status")" "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'fortad_exact_behavior: check=pass forward=expected-refusal-undeclared-a reverse=expected-refusal-undeclared-a no-derivative-output\n'
    printf 'independent_oracle: %s\n' "$oracle_output"
    printf 'upstream_sha256:\n'; (cd "$source_dir" && sha256sum program.f program_d.f program_d.msg Options PUSHPOPGeneralLib)
    printf 'fresh_tapenade_sha256:\n'; (cd "$out/fresh/parser" && sha256sum lh089_p.f lh089_p.msg); (cd "$out/fresh/forward" && sha256sum lh089_d.f lh089_d.msg); (cd "$out/fresh/reverse" && sha256sum lh089_b.f lh089_b.msg)
    printf 'case_artifact_sha256:\n'; (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
