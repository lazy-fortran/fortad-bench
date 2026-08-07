#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=72ca2aa1c6c7d4b171b13a3e13c5190944080032
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/ala04
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-ala04.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$fortad_repo" branch --show-current)" = main
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad" && test -x "$tapenade"
for source in Options program.f program_p.f program_p.msg program_d.f program_d.msg program_b.f program_b.msg; do
    test -e "$source_dir/$source"
done

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

for file in program.f program_p.f program_d.f program_b.f; do
    label=${file%.f}
    run_status "exact-strict-$label" "$fc" "${strict[@]}" "$source_dir/$file"
    run_status "exact-legacy-$label" "$fc" "${legacy[@]}" "$source_dir/$file"
    test "$(status "exact-strict-$label")" -ne 0
    grep -Fq 'REAL*8' "$out/exact-strict-$label.stderr"
    test "$(status "exact-legacy-$label")" -eq 0
done

run_status exact-primal-build "$fc" -std=legacy -ffixed-form -ffixed-line-length-none \
    -Wall -Wextra -Wimplicit-interface -fno-lto "$source_dir/program.f" \
    -o "$out/exact-primal"
test "$(status exact-primal-build)" -eq 0
run_status exact-primal-run "$out/exact-primal"
test "$(status exact-primal-run)" -eq 0
grep -Eq '0\.999999999' "$out/exact-primal-run.stdout"

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p ;;
        forward) flag=-d; suffix=d ;;
        reverse) flag=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode" "$tapenade" "$flag" -context \
        -O "$out/fresh/$mode" -o ala04 "$source_dir/program.f"
    generated="$out/fresh/$mode/ala04_${suffix}.f"
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$generated"
    test -e "$out/fresh/$mode/ala04_${suffix}.msg"
    run_status "fresh-strict-$mode" "$fc" "${strict[@]}" "$generated"
    run_status "fresh-legacy-$mode" "$fc" "${legacy[@]}" "$generated"
    test "$(status "fresh-strict-$mode")" -ne 0
    grep -Fq 'REAL*8' "$out/fresh-strict-$mode.stderr"
    test "$(status "fresh-legacy-$mode")" -eq 0
    diff -I '^C  Tapenade ' "$source_dir/program_${suffix}.f" "$generated" >/dev/null
done

normalize_message() { sed -E 's/^[0-9]+[[:space:]]*//' "$1"; }
for suffix in p d b; do
    normalize_message "$source_dir/program_${suffix}.msg" >"$out/stored-${suffix}.msg"
    if test "$suffix" = p; then mode=parser; elif test "$suffix" = d; then mode=forward; else mode=reverse; fi
    normalize_message "$out/fresh/$mode/ala04_${suffix}.msg" >"$out/fresh-${suffix}.msg"
    cmp -s "$out/stored-${suffix}.msg" "$out/fresh-${suffix}.msg"
done

mkdir -p "$out/fortad"
run_status fortad-check "$fortad" check --proc FP2 --output "$out/fortad/check.f90" "$source_dir/program.f"
test "$(status fortad-check)" -eq 0
test -s "$out/fortad/check.f90"
grep -Fq 'subroutine FP2(x, y)' "$out/fortad/check.f90"
grep -Fq 'y = z * x' "$out/fortad/check.f90"
! grep -Fq 'REAL*8' "$out/fortad/check.f90"
! grep -Fq 'DO WHILE' "$out/fortad/check.f90"

run_status fortad-forward "$fortad" --mode forward --proc FP2 --indep x --dep y \
    --name ala04_d --module ala04_d_mod --output "$out/fortad/forward.f90" "$source_dir/program.f"
test "$(status fortad-forward)" -ne 0
grep -Fq "independent 'x' is not declared in FP2" "$out/fortad-forward.stdout" "$out/fortad-forward.stderr"
test ! -e "$out/fortad/forward.f90"

run_status fortad-reverse "$fortad" --mode reverse --proc FP2 --indep x --dep y \
    --name ala04_b --module ala04_b_mod --output "$out/fortad/reverse.f90" "$source_dir/program.f"
test "$(status fortad-reverse)" -ne 0
grep -Fq "dependent 'y' is not declared in FP2" "$out/fortad-reverse.stdout" "$out/fortad-reverse.stderr"
test ! -e "$out/fortad/reverse.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions/set01/ala04\n'
    printf 'classification: expected-refusal-fortad-real8-declaration-boundary\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict[*]}"
    printf 'legacy_flags: %s\n' "${legacy[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: FP2(x,y)\n'
    printf 'tapenade_options: parser=-p -context forward=-d -context reverse=-b -context\n'
    printf 'exact_strict_compile: program=%s program_p=%s program_d=%s program_b=%s diagnostic=REAL8\n' \
        "$(status exact-strict-program)" "$(status exact-strict-program_p)" \
        "$(status exact-strict-program_d)" "$(status exact-strict-program_b)"
    printf 'exact_legacy_compile: program=%s program_p=%s program_d=%s program_b=%s\n' \
        "$(status exact-legacy-program)" "$(status exact-legacy-program_p)" \
        "$(status exact-legacy-program_d)" "$(status exact-legacy-program_b)"
    printf 'exact_primal_runtime: build=%s run=%s output=%s\n' \
        "$(status exact-primal-build)" "$(status exact-primal-run)" \
        "$(tr '\n' ' ' <"$out/exact-primal-run.stdout")"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s diagnostic=REAL8\n' \
        "$(status fresh-strict-parser)" "$(status fresh-strict-forward)" "$(status fresh-strict-reverse)"
    printf 'tapenade_fresh_legacy_compile: parser=%s forward=%s reverse=%s\n' \
        "$(status fresh-legacy-parser)" "$(status fresh-legacy-forward)" "$(status fresh-legacy-reverse)"
    printf 'tapenade_reference_match: parser=normalized-banner forward=normalized-banner reverse=normalized-banner messages=normalized-number-prefix\n'
    printf 'fortad_exact_behavior: check=exit-0-non-equivalent-reemit-missing-REAL8-and-DO-WHILE forward=expected-refusal-independent-x-not-declared reverse=expected-refusal-dependent-y-not-declared no-derivative-output\n'
    printf 'independent_oracle: nested-primal jvp-central-difference vjp-dot-product\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: true\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f \
        "$source_rel"/program_p.f "$source_rel"/program_p.msg "$source_rel"/program_d.f \
        "$source_rel"/program_d.msg "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/ala04_p.f parser/ala04_p.msg \
        forward/ala04_d.f forward/ala04_d.msg reverse/ala04_b.f reverse/ala04_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
