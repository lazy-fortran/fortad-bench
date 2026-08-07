#!/usr/bin/env bash
# Probe Tapenade's abstract/deferred OO case and the corresponding FortAD boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
case_dir="$tapenade_repo/nonRegressions/set12/f03typf01"
port_dir="$root/cases/itpplasma/abstract_deferred_refusal"
result="$root/results/tapenade_f03typf01_oo_validation.txt"
fc=${FC:-gfortran}
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
compile_flags=(-std=f2018 -ffree-line-length-none -pedantic-errors)

command -v "$fc" >/dev/null
command -v fo >/dev/null
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -f "$case_dir/program.f90"
test -f "$case_dir/program_p.f90"
test -f "$tapenade_repo/bin/tapenade"

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-f03typf01-oo.XXXXXX")

for source in program.f90 program_p.f90; do
    "$fc" "${compile_flags[@]}" -fsyntax-only "$case_dir/$source" \
        >"$out/$source.compile.stdout" 2>"$out/$source.compile.stderr"
done

tap_out="$out/tapenade"
mkdir -p "$tap_out"
set +e
(
    cd "$case_dir"
    PATH="$tapenade_repo/bin:$PATH" "$tapenade_repo/bin/tapenade" \
        -p -O "$tap_out" program.f90
) >"$out/tapenade.stdout" 2>"$out/tapenade.stderr"
tap_status=$?
set -e
test "$tap_status" -eq 0
test -f "$tap_out/program_p.f90"

set +e
"$fc" "${compile_flags[@]}" -fsyntax-only "$tap_out/program_p.f90" \
    >"$out/generated.compile.stdout" 2>"$out/generated.compile.stderr"
generated_status=$?
set -e
test "$generated_status" -ne 0
grep -Fq "being used before it is defined" "$out/generated.compile.stderr"
grep -Fq "should be declared DEFERRED" "$out/generated.compile.stderr"

# Compile/run the parser-compatible port with an independent child-value and
# central-difference oracle. The shared boundary runner also covers ownership
# and callback cases, so this focused check only needs the abstract module.
port_mod="$out/port-mod"
mkdir -p "$port_mod"
"$fc" "${compile_flags[@]}" -O2 -J"$port_mod" -I"$port_mod" \
    -c "$port_dir/primal.f90" -o "$out/port.o"
"$fc" "${compile_flags[@]}" -O2 -J"$port_mod" -I"$port_mod" \
    -c "$root/harness/check_tapenade_f03typf01.f90" -o "$out/oracle.o"
"$fc" "${compile_flags[@]}" -O2 -o "$out/oracle" \
    "$out/port.o" "$out/oracle.o"
"$out/oracle" >"$out/oracle.txt"
grep -Fqx "PASS: Tapenade f03typf01 primal and finite-difference oracle" \
    "$out/oracle.txt"

refusal="$out/fortad-refusal.f90"
set +e
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep x \
        --proc evaluate_deferred --name evaluate_deferred_jvp \
        --module f03typf01_refusal_ad --output "$refusal" \
        "$port_dir/primal.f90"
) >"$out/fortad.stdout" 2>"$out/fortad.stderr"
fortad_status=$?
set -e
test "$fortad_status" -ne 0
grep -Fq "fortad: unsupported type-bound call 'value': the concrete type is not defined in this source" \
    "$out/fortad.stderr"
test ! -e "$refusal"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
{
    printf 'case: Tapenade nonRegressions/set12/f03typf01 OO boundary\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'upstream_primal_compile: pass\n'
    printf 'upstream_reference_compile: pass\n'
    printf 'tapenade_parser_status: %s\n' "$tap_status"
    printf 'tapenade_generated_source: program_p.f90\n'
    printf 'tapenade_generated_compile_status: %s (expected rejection)\n' \
        "$generated_status"
    printf 'tapenade_generated_diagnostic: abstract type regenerated without ABSTRACT; deferred PROCEDURE declaration invalid\n'
    printf 'ported_primal_oracle: pass (two concrete children and central finite differences)\n'
    printf 'fortad_status: expected-refusal\n'
    printf 'fortad_refusal_status: %s\n' "$fortad_status"
    printf "fortad_diagnostic: unsupported type-bound call 'value': the concrete type is not defined in this source\n"
    printf 'oracle_contract: dynamic child selection is passive; x is the only differentiated scalar\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set12/f03typf01.toml \
        cases/tapenade-set12/f03typf01.md \
        cases/itpplasma/abstract_deferred_refusal/primal.f90 \
        harness/check_tapenade_f03typf01.f90 \
        scripts/bench_tapenade_f03typf01_oo.sh)
    printf 'oracle_output:\n'
    cat "$out/oracle.txt"
} >"$result"

cat "$result"
