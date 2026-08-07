#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade"}
required_fortad=a1c9f25f87eaadf700ba47ee3e841a0fb41585a3
required_tapenade=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/nonRegressions/set01/lh095"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh095.XXXXXX)
trap 'rm -rf "$out"' EXIT

actual_fortad=$(git -C "$fortad_repo" rev-parse HEAD)
actual_tapenade=$(git -C "$tapenade_repo" rev-parse HEAD)
if test "$actual_fortad" != "$required_fortad"; then
    printf 'blocked: FortAD checkout is %s; required %s\n' "$actual_fortad" "$required_fortad" >&2
    exit 1
fi
if test "$actual_tapenade" != "$required_tapenade"; then
    printf 'blocked: Tapenade checkout is %s; required %s\n' "$actual_tapenade" "$required_tapenade" >&2
    exit 1
fi
test -x "$fortad"; test -x "$tapenade"; command -v "$fc" >/dev/null
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do test -s "$source_dir/$source"; done

strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only)
run_status() { local label=$1; shift; set +e; "$@" >"$out/$label.out" 2>&1; local status=$?; set -e; printf '%s\n' "$status" >"$out/$label.status"; }
status() { cat "$out/$1.status"; }

for source in program.f program_p.f program_d.f program_b.f; do
    label=stored-${source%.f}
    run_status "$label" "$fc" "${strict_fixed[@]}" "$source_dir/$source"
    test "$(status "$label")" -eq 0
done
run_status stored-program_dv "$fc" "${strict_fixed[@]}" "$source_dir/program_dv.f"
test "$(status stored-program_dv)" -ne 0
grep -Fq 'DIFFSIZES.inc' "$out/stored-program_dv.out"

for mode in parser forward reverse; do
    mkdir -p "$out/fresh/$mode"
    case "$mode" in parser) option=-p; suffix=p; extra=();; forward) option=-d; suffix=d; extra=(-root testliveness);; reverse) option=-b; suffix=b; extra=(-root testliveness);; esac
    run_status "fresh-$mode" "$tapenade" "$option" "${extra[@]}" -O "$out/fresh/$mode" -o lh095 "$source_dir/program.f"
    test "$(status "fresh-$mode")" -eq 0
    generated="$out/fresh/$mode/lh095_${suffix}.f"
    test -s "$generated"
    run_status "fresh-$mode-compile" "$fc" "${strict_fixed[@]}" "$generated"
    test "$(status "fresh-$mode-compile")" -eq 0
done

run_status fortad-source-check "$fortad" check --proc testliveness --output "$out/source-check.f90" "$source_dir/program.f"
test "$(status fortad-source-check)" -eq 0; test -s "$out/source-check.f90"
run_status fortad-source-forward "$fortad" jvp "$source_dir/program.f" a --proc testliveness --dep b --output "$out/source-forward.f90"
test "$(status fortad-source-forward)" -eq 0; test -s "$out/source-forward.f90"
run_status fortad-source-reverse "$fortad" vjp "$source_dir/program.f" a --proc testliveness --dep b --output "$out/source-reverse.f90"
test "$(status fortad-source-reverse)" -ne 0; grep -Fq "assignment to undeclared 'sub1'" "$out/fortad-source-reverse.out"; test ! -e "$out/source-reverse.f90"

mkdir -p "$out/compat-p" "$out/compat-d"
run_status fortad-compat-parser "$fortad" -p -root testliveness -O "$out/compat-p" -o lh095 "$source_dir/program.f"
run_status fortad-compat-forward "$fortad" -d -root testliveness -O "$out/compat-d" -o lh095 "$source_dir/program.f"
test "$(status fortad-compat-parser)" -eq 0; test -s "$out/compat-p/lh095_p.f90"
test "$(status fortad-compat-forward)" -eq 0; test -s "$out/compat-d/lh095_d.f90"
run_status fortad-compat-reverse "$fortad" -b -root testliveness --dep b -O "$out" -o lh095 "$source_dir/program.f"
test "$(status fortad-compat-reverse)" -ne 0; grep -Fq "assignment to undeclared 'sub1'" "$out/fortad-compat-reverse.out"

oracle=$(python3 "$case_dir/oracle.py")
grep -Fqx 'oracle_status: pass' <<<"$oracle"
printf '%s\n' 'case: Tapenade nonRegressions/set01/lh095' 'runner_result: pass' \
    'stored_strict_compile: primal=0 parser=0 forward=0 reverse=0 multidirectional=expected-refusal-missing-DIFFSIZES.inc' \
    'fresh_tapenade: parser=0 forward=0 reverse=0; all strict compile=0' \
    'fortad_source_first: check=0 forward=0 reverse=expected-refusal-undeclared-sub1' \
    'fortad_compatibility: parser=0 forward=0 reverse=expected-refusal-undeclared-sub1' \
    'independent_oracle: 3 cases, finite-difference JVP, reverse dot-product identity' \
    "$oracle" >"$result"
printf 'lh095 runner: pass (%s)\n' "$result"
