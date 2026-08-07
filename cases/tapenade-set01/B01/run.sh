#!/usr/bin/env bash
# Exact-source B01 runner; all generated artifacts stay in a temporary directory.
set -euo pipefail
case_dir=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$root/../fortad
tapenade_repo=$root/upstream/tapenade
if printenv FORTAD_REPO >/dev/null 2>&1; then fortad_repo=$(printenv FORTAD_REPO); fi
if printenv TAPENADE_REPO >/dev/null 2>&1; then tapenade_repo=$(printenv TAPENADE_REPO); fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=72ca2aa1c6c7d4b171b13a3e13c5190944080032
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=gfortran
if printenv FC >/dev/null 2>&1; then fc=$(printenv FC); fi
source_rel=nonRegressions/set01/B01
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-B01.XXXXXX)
trap 'rm -rf "$out"' EXIT
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -x "$fortad"
test -x "$tapenade"
for source in Param3D.h Paramopt3D.h Paramopt3D_b.h Paramopt3D_d.h program.f program_d.f program_d.msg program_b.f program_b.msg; do
    test -s "$source_dir/$source"
done
strict_flags="-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only"
legacy_flags="-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface -fsyntax-only"
run_status() {
    local label=$1
    shift
    local command_status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || command_status=$?
    printf '%s\n' "$command_status" >"$out/$label.status"
}
status() { cat "$out/$1.status"; }
compile_source() {
    local label=$1
    local source=$2
    local mode=$3
    if test "$mode" = strict; then
        run_status "$label" "$fc" -std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only -I "$source_dir" "$source"
    else
        run_status "$label" "$fc" -std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface -fsyntax-only -I "$source_dir" "$source"
    fi
}
for source in program.f program_d.f program_b.f; do
    compile_source "exact-$source-strict" "$source_dir/$source" strict
    compile_source "exact-$source-legacy" "$source_dir/$source" legacy
    test "$(status "exact-$source-strict")" -ne 0
    grep -Fq "REAL*8" "$out/exact-$source-strict.stdout" "$out/exact-$source-strict.stderr"
    test "$(status "exact-$source-legacy")" -eq 0
done
mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
run_tapenade() {
    local mode=$1
    local work="$out/fresh/$mode"
    local command_status=0
    if test "$mode" = parser; then
        (cd "$work" && "$tapenade" -p -O . -o b01 "$source_dir/program.f") >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr" || command_status=$?
    elif test "$mode" = forward; then
        (cd "$work" && "$tapenade" -d -root gradfb -O . -o b01 "$source_dir/program.f") >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr" || command_status=$?
    else
        (cd "$work" && "$tapenade" -b -root gradfb -O . -o b01 "$source_dir/program.f") >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr" || command_status=$?
    fi
    printf '%s\n' "$command_status" >"$out/tapenade-$mode.status"
}
run_tapenade parser
run_tapenade forward
run_tapenade reverse
for mode in parser forward reverse; do
    suffix=p
    if test "$mode" = forward; then suffix=d; elif test "$mode" = reverse; then suffix=b; fi
    generated="$out/fresh/$mode/b01_$suffix.f"
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$generated"
    test -s "$out/fresh/$mode/b01_$suffix.msg"
    compile_source "fresh-$mode-strict" "$generated" strict
    compile_source "fresh-$mode-legacy" "$generated" legacy
    test "$(status "fresh-$mode-strict")" -ne 0
    grep -Fq "REAL*8" "$out/fresh-$mode-strict.stdout" "$out/fresh-$mode-strict.stderr"
    test "$(status "fresh-$mode-legacy")" -eq 0
done
run_status fortad-check "$fortad" check --proc gradfb --output "$out/fortad-check.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" jvp x,y,z --proc gradfb --name b01_jvp --module b01_jvp_mod --output "$out/fortad-forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" vjp x,y,z --dep vol6 --proc gradfb --name b01_vjp --module b01_vjp_mod --output "$out/fortad-reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do
    test "$(status "fortad-$mode")" -ne 0
    grep -Fq "could not locate the end of this do construct" "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    test ! -e "$out/fortad-$mode.f90"
done
oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_behavioral_cases: 3" <<<"$oracle_output"
grep -Fqx "oracle_status: pass" <<<"$oracle_output"
cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions/set01/B01 GRADFB\n'
    printf 'case_id: B01\n'
    printf 'classification: expected-refusal-fortad-legacy-do-line-116\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_flags: %s\n' "$strict_flags"
    printf 'legacy_flags: %s\n' "$legacy_flags"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: gradfb(x,y,z,b,c,d,vol6)\n'
    printf 'tapenade_options: parser=-p forward=-d/-root gradfb reverse=-b/-root gradfb\n'
    printf 'upstream_strict_compile: program=%s program_d=%s program_b=%s\n' "$(status exact-program.f-strict)" "$(status exact-program_d.f-strict)" "$(status exact-program_b.f-strict)"
    printf 'upstream_legacy_compile: program=%s program_d=%s program_b=%s\n' "$(status exact-program.f-legacy)" "$(status exact-program_d.f-legacy)" "$(status exact-program_b.f-legacy)"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'fresh_strict_compile: parser=%s forward=%s reverse=%s\n' "$(status fresh-parser-strict)" "$(status fresh-forward-strict)" "$(status fresh-reverse-strict)"
    printf 'fresh_legacy_compile: parser=%s forward=%s reverse=%s\n' "$(status fresh-parser-legacy)" "$(status fresh-forward-legacy)" "$(status fresh-reverse-legacy)"
    printf 'fortad_exact_behavior: check=%s jvp=%s vjp=%s diagnostic=legacy-do-line-116 no-output\n' "$(status fortad-check)" "$(status fortad-forward)" "$(status fortad-reverse)"
    printf 'independent_oracle: determinant-volume JVP-finite-difference VJP-adjoint\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: exact-source-only\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Param3D.h "$source_rel"/Paramopt3D.h "$source_rel"/Paramopt3D_b.h "$source_rel"/Paramopt3D_d.h "$source_rel"/program.f "$source_rel"/program_d.f "$source_rel"/program_d.msg "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/fresh/parser/b01_p.f" "$out/fresh/parser/b01_p.msg" "$out/fresh/forward/b01_d.f" "$out/fresh/forward/b01_d.msg" "$out/fresh/reverse/b01_b.f" "$out/fresh/reverse/b01_b.msg"
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
