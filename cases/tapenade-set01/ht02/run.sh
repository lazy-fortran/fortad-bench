#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=93f41d60d882778699ec1a887ce9a665a75afcf8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/ht02
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-ht02.XXXXXX)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
# The shared FortAD checkout may carry unrelated documentation work; the exact
# HEAD pin above is the source revision used by this case.
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in program.f program_b.f program_b.msg; do
    test -s "$source_dir/$source"
done

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fsyntax-only)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none
    -Wall -Wextra -Wimplicit-interface -fsyntax-only)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

run_tapenade() {
    local label=$1
    local work=$2
    shift 2
    local status=0
    (cd "$work" && "$tapenade" "$@" -O . -o ht02 "$source_dir/program.f") \
        >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"

run_status exact-strict "$fc" "${strict[@]}" "$source_dir/program.f"
run_status exact-legacy "$fc" "${legacy[@]}" "$source_dir/program.f"
run_status stored-strict "$fc" "${strict[@]}" "$source_dir/program_b.f"
run_status stored-legacy "$fc" "${legacy[@]}" "$source_dir/program_b.f"
for label in exact-strict exact-legacy stored-strict stored-legacy; do
    test "$(status "$label")" -eq 0
done

run_tapenade tapenade-parser "$out/fresh/parser" -p
run_tapenade tapenade-forward "$out/fresh/forward" -d -root top
run_tapenade tapenade-reverse "$out/fresh/reverse" -b -root top

for mode in parser forward reverse; do
    suffix=p
    test "$mode" = forward && suffix=d
    test "$mode" = reverse && suffix=b
    generated="$out/fresh/$mode/ht02_${suffix}.f"
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$generated"
    test -f "$out/fresh/$mode/ht02_${suffix}.msg"
    run_status "fresh-$mode-strict" "$fc" "${strict[@]}" "$generated"
    run_status "fresh-$mode-legacy" "$fc" "${legacy[@]}" "$generated"
    test "$(status "fresh-$mode-strict")" -eq 0
    test "$(status "fresh-$mode-legacy")" -eq 0
done

run_status fortad-check "$fortad" check --proc top \
    --output "$out/fortad-check.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" jvp a --proc top --name ht02_jvp \
    --module ht02_jvp_mod --output "$out/fortad-forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" vjp a --dep a --proc top --name ht02_vjp \
    --module ht02_vjp_mod --output "$out/fortad-reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do
    test "$(status "fortad-$mode")" -ne 0
    grep -Fq "unsupported statement at line 7" \
        "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    test ! -e "$out/fortad-$mode.f90"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_behavioral_cases: 3" <<<"$oracle_output"
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions/set01/ht02\n'
    printf 'classification: expected-refusal-fortad-unsupported-I-O-line-7\n'
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
    printf 'upstream_entry_point: top(a)\n'
    printf 'strict_compile: exact=%s stored_reverse=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' \
        "$(status exact-strict)" "$(status stored-strict)" \
        "$(status fresh-parser-strict)" "$(status fresh-forward-strict)" \
        "$(status fresh-reverse-strict)"
    printf 'legacy_compile: exact=%s stored_reverse=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' \
        "$(status exact-legacy)" "$(status stored-legacy)" \
        "$(status fresh-parser-legacy)" "$(status fresh-forward-legacy)" \
        "$(status fresh-reverse-legacy)"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'fortad_exact_behavior: check=%s forward=%s reverse=%s diagnostic=unsupported-statement-line-7 no-output\n' \
        "$(status fortad-check)" "$(status fortad-forward)" "$(status fortad-reverse)"
    printf 'independent_oracle: fixed-external-read JVP-finite-difference VJP-adjoint\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: exact-source-only\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/ht02_p.f parser/ht02_p.msg forward/ht02_d.f forward/ht02_d.msg reverse/ht02_b.f reverse/ht02_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
