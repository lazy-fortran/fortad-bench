#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh091 exact-source boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh091"
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=150e663dbad239a3a11a679e3dcf16be76496f8d
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/lh091
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh091.XXXXXX)
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

for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for message in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -f "$source_dir/$message"
done
test ! -e "$source_dir/DIFFSIZES.inc"

strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only -I "$source_dir")
legacy_flags=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface -fsyntax-only -I "$source_dir")
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
        run_status "$label" "$fc" "${strict_flags[@]}" "$source"
    else
        run_status "$label" "$fc" "${legacy_flags[@]}" "$source"
    fi
}

for source in program.f program_p.f program_d.f program_b.f; do
    compile_source "exact-$source-strict" "$source_dir/$source" strict
    compile_source "exact-$source-legacy" "$source_dir/$source" legacy
    test "$(status "exact-$source-strict")" -eq 0
    test "$(status "exact-$source-legacy")" -eq 0
done
compile_source exact-program_dv.f-strict "$source_dir/program_dv.f" strict
compile_source exact-program_dv.f-legacy "$source_dir/program_dv.f" legacy
for mode in strict legacy; do
    test "$(status "exact-program_dv.f-$mode")" -ne 0
    grep -Fq "DIFFSIZES.inc" "$out/exact-program_dv.f-$mode.stdout" "$out/exact-program_dv.f-$mode.stderr"
done

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
run_status tapenade-parser "$tapenade" -p -O "$out/fresh/parser" -o lh091 "$source_dir/program.f"
run_status tapenade-forward "$tapenade" -d -root bugequiv -O "$out/fresh/forward" -o lh091 "$source_dir/program.f"
run_status tapenade-reverse "$tapenade" -b -root bugequiv -O "$out/fresh/reverse" -o lh091 "$source_dir/program.f"
for mode in parser forward reverse; do
    suffix=p
    if test "$mode" = forward; then suffix=d; elif test "$mode" = reverse; then suffix=b; fi
    generated="$out/fresh/$mode/lh091_$suffix.f"
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$generated"
    test -s "$out/fresh/$mode/lh091_$suffix.msg"
    compile_source "fresh-$mode-strict" "$generated" strict
    compile_source "fresh-$mode-legacy" "$generated" legacy
    test "$(status "fresh-$mode-strict")" -eq 0
    test "$(status "fresh-$mode-legacy")" -eq 0
done

mkdir -p "$out/compat-p" "$out/compat-d" "$out/compat-b"
run_status fortad-source-check "$fortad" check --proc bugequiv --output "$out/source-check.f90" "$source_dir/program.f"
run_status fortad-source-jvp "$fortad" jvp c --proc bugequiv --name lh091_jvp --module lh091_jvp_mod --output "$out/source-jvp.f90" "$source_dir/program.f"
run_status fortad-source-vjp "$fortad" vjp c --dep c --proc bugequiv --name lh091_vjp --module lh091_vjp_mod --output "$out/source-vjp.f90" "$source_dir/program.f"
run_status fortad-compat-p "$fortad" -p -O "$out/compat-p" -o lh091 "$source_dir/program.f"
run_status fortad-compat-d "$fortad" -d -root bugequiv -O "$out/compat-d" -o lh091 "$source_dir/program.f"
run_status fortad-compat-b "$fortad" -b -root bugequiv -O "$out/compat-b" -o lh091 "$source_dir/program.f"
for mode in source-check source-jvp source-vjp compat-p compat-d compat-b; do
    test "$(status "fortad-$mode")" -ne 0
    grep -Fq "unsupported statement at line 7" "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
done
test ! -e "$out/source-check.f90"
test ! -e "$out/source-jvp.f90"
test ! -e "$out/source-vjp.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_behavioral_cases: 3" <<<"$oracle_output"
grep -Fqx "oracle_status: pass" <<<"$oracle_output"
cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set01 lh091\n'
    printf 'classification: expected-refusal-fortad-common-equivalence-and-missing-diffsizes\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_flags[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: bugequiv(c); FF(x)\n'
    printf 'tapenade_options: parser=-p forward=-d/-root bugequiv reverse=-b/-root bugequiv\n'
    printf 'exact_compile: program=0/0 parser=0/0 forward=0/0 reverse=0/0 dv=%s/%s missing-DIFFSIZES.inc\n' "$(status exact-program_dv.f-strict)" "$(status exact-program_dv.f-legacy)"
    printf 'fresh_tapenade_generation: parser=%s forward=%s reverse=%s\n' "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'fresh_compile: parser=0/0 forward=0/0 reverse=0/0 strict/legacy\n'
    printf 'fortad_source_first: check=%s jvp=%s vjp=%s diagnostic=unsupported-statement-line-7-no-output\n' "$(status fortad-source-check)" "$(status fortad-source-jvp)" "$(status fortad-source-vjp)"
    printf 'fortad_compatibility: p=%s d=%s b=%s diagnostic=unsupported-statement-line-7-no-output\n' "$(status fortad-compat-p)" "$(status fortad-compat-d)" "$(status fortad-compat-b)"
    printf 'independent_oracle: FF-update-three-cases JVP-finite-difference VJP-adjoint\n'
    printf '%s\n' "$oracle_output"
    printf 'missing_dependency: DIFFSIZES.inc absent; no authoritative substitution\n'
    printf 'no_repaired_port: exact-source-only\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_p.f "$source_rel"/program_p.msg "$source_rel"/program_d.f "$source_rel"/program_d.msg "$source_rel"/program_b.f "$source_rel"/program_b.msg "$source_rel"/program_dv.f "$source_rel"/program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/fresh/parser/lh091_p.f" "$out/fresh/parser/lh091_p.msg" "$out/fresh/forward/lh091_d.f" "$out/fresh/forward/lh091_d.msg" "$out/fresh/reverse/lh091_b.f" "$out/fresh/reverse/lh091_b.msg"
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh091/manifest.toml cases/tapenade-set01/lh091/notes.md cases/tapenade-set01/lh091/oracle.py cases/tapenade-set01/lh091/run.sh cases/tapenade-set01/lh091/test_contract.py)
} >"$result"
cat "$result"
