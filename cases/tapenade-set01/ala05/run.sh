#!/usr/bin/env bash
# Validate the pinned Tapenade set01/ala05 exact-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=72ca2aa1c6c7d4b171b13a3e13c5190944080032
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/ala05
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-ala05.XXXXXX)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git" && test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" branch --show-current)" = main
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad" && test -x "$tapenade"
for source in Options program.f90 program_p.f90 program_p.msg program_d.f90 program_d.msg program_b.f90 program_b.msg; do
    test -e "$source_dir/$source"
done

strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy=(-std=legacy -ffree-form -ffree-line-length-none -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}
status() { cat "$out/$1.status"; }

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" "$out/fortad"

for file in program.f90 program_p.f90 program_d.f90 program_b.f90; do
    label=${file%.f90}
    run_status "exact-strict-$label" "$fc" "${strict[@]}" "$source_dir/$file"
    run_status "exact-legacy-$label" "$fc" "${legacy[@]}" "$source_dir/$file"
done
for label in exact-strict-program exact-strict-program_p exact-strict-program_d; do test "$(status "$label")" -eq 0; done
test "$(status exact-strict-program_b)" -ne 0
grep -Fq 'Nonstandard type declaration REAL*8' "$out/exact-strict-program_b.stderr"
for label in exact-legacy-program exact-legacy-program_p exact-legacy-program_d exact-legacy-program_b; do test "$(status "$label")" -eq 0; done

run_status exact-primal-build "$fc" -std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface "$source_dir/program.f90" -o "$out/exact-primal"
test "$(status exact-primal-build)" -eq 0
run_status exact-primal-runtime "$out/exact-primal"
test "$(status exact-primal-runtime)" -eq 0
grep -Fq '2.346524320087' "$out/exact-primal-runtime.stdout"

for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p ;;
        forward) flag=-d; suffix=d ;;
        reverse) flag=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode" "$tapenade" "$flag" -head 'NFP(y)/(x)' -context -fixinterface -O "$out/fresh/$mode" -o ala05 "$source_dir/program.f90"
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$out/fresh/$mode/ala05_${suffix}.f90"
    test -e "$out/fresh/$mode/ala05_${suffix}.msg"
    run_status "fresh-$mode-strict" "$fc" "${strict[@]}" "$out/fresh/$mode/ala05_${suffix}.f90"
    run_status "fresh-$mode-legacy" "$fc" "${legacy[@]}" "$out/fresh/$mode/ala05_${suffix}.f90"
done
for label in fresh-parser-strict fresh-parser-legacy fresh-forward-strict fresh-forward-legacy; do test "$(status "$label")" -eq 0; done
test "$(status fresh-reverse-strict)" -ne 0
grep -Fq 'Nonstandard type declaration REAL*8' "$out/fresh-reverse-strict.stderr"
test "$(status fresh-reverse-legacy)" -eq 0

without_banner() { sed '/^!  Tapenade /d' "$1"; }
diff -u <(without_banner "$source_dir/program_p.f90") <(without_banner "$out/fresh/parser/ala05_p.f90") >/dev/null
diff -u <(without_banner "$source_dir/program_d.f90") <(without_banner "$out/fresh/forward/ala05_d.f90") >/dev/null
grep -Fq 'ADSTACK_STARTREPEAT' "$out/fresh/reverse/ala05_b.f90"
grep -Fq 'ADSTACK_ENDREPEAT' "$out/fresh/reverse/ala05_b.f90"
grep -Fq 'zbconv' "$source_dir/program_b.f90"

run_status fortad-check "$fortad" check --proc NFP --output "$out/fortad/check.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --proc NFP --indep x --dep y --name ala05_d --module ala05_d_mod --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --proc NFP --indep x --dep y --name ala05_b --module ala05_b_mod --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
for mode in check forward reverse; do
    test "$(status "fortad-$mode")" -ne 0
    grep -Fq 'fortad: parse failed: ERROR at line 27, column 16: Unrecognized statement: DO WHILE (' "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    test ! -e "$out/fortad/$mode.f90"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f90")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions/set01/ala05\n'
    printf 'classification: expected-refusal-fortad-unsupported-do-while-line-27-and-tapenade-reverse-real8\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'exact_compile: strict=program/parser/forward-pass reverse=REAL8-refusal legacy=all-pass\n'
    printf 'exact_primal_runtime: build=0 run=0 output=2.346524320087...\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'tapenade_fresh_strict: parser=%s forward=%s reverse=%s-REAL8-refusal\n' "$(status fresh-parser-strict)" "$(status fresh-forward-strict)" "$(status fresh-reverse-strict)"
    printf 'tapenade_fresh_legacy: parser=%s forward=%s reverse=%s\n' "$(status fresh-parser-legacy)" "$(status fresh-forward-legacy)" "$(status fresh-reverse-legacy)"
    printf 'tapenade_reference_match: parser-and-forward-after-banner-normalization\n'
    printf 'tapenade_reverse_difference: fresh=ADSTACK_STARTREPEAT/ENDREPEAT stored=zbconv\n'
    printf 'fortad_exact_behavior: check/forward/reverse=expected-refusal unsupported-DO-WHILE-line-27 no-output\n'
    printf 'independent_oracle: exact-source-shape default-real-increment primal jvp-finite-difference vjp-dot-product\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: true\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f90 "$source_rel"/program_p.f90 "$source_rel"/program_p.msg "$source_rel"/program_d.f90 "$source_rel"/program_d.msg "$source_rel"/program_b.f90 "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/ala05_p.f90 parser/ala05_p.msg forward/ala05_d.f90 forward/ala05_d.msg reverse/ala05_b.f90 reverse/ala05_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
