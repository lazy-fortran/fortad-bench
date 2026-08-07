#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=8137837b6c474708c20ea86ad02b086aa15322fd
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/ala02
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-ala02.XXXXXX)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"

for source in Options program.f program_p.f program_p.msg program_d.f program_d.msg program_b.f program_b.msg; do
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

status() { cat "$out/$1.status"; }

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
mkdir -p "$out/compat/parser" "$out/compat/forward" "$out/compat/reverse"

run_status exact-strict "$fc" "${strict[@]}" "$source_dir/program.f"
run_status exact-legacy "$fc" "${legacy[@]}" "$source_dir/program.f"
for reference in p d b; do
    run_status "stored-${reference}-strict" "$fc" "${strict[@]}" "$source_dir/program_${reference}.f"
    run_status "stored-${reference}-legacy" "$fc" "${legacy[@]}" "$source_dir/program_${reference}.f"
done
test "$(status exact-strict)" -eq 0
test "$(status exact-legacy)" -eq 0
test "$(status stored-p-strict)" -eq 0
test "$(status stored-p-legacy)" -eq 0
test "$(status stored-d-strict)" -eq 0
test "$(status stored-d-legacy)" -eq 0
test "$(status stored-b-strict)" -ne 0
test "$(status stored-b-legacy)" -eq 0

run_status tapenade-parser "$tapenade" -p -context -fixinterface -standalonediff \
    -O "$out/fresh/parser" -o ala02 "$source_dir/program.f"
run_status tapenade-forward "$tapenade" -d -root root -context -fixinterface -standalonediff \
    -O "$out/fresh/forward" -o ala02 "$source_dir/program.f"
run_status tapenade-reverse "$tapenade" -b -root root -context -fixinterface -standalonediff \
    -O "$out/fresh/reverse" -o ala02 "$source_dir/program.f"
for mode in parser forward reverse; do
    case "$mode" in
        parser) suffix=p ;;
        forward) suffix=d ;;
        reverse) suffix=b ;;
    esac
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$out/fresh/$mode/ala02_${suffix}.f"
    test -s "$out/fresh/$mode/ala02_${suffix}.msg"
done

run_status fresh-parser-strict "$fc" "${strict[@]}" "$out/fresh/parser/ala02_p.f"
run_status fresh-parser-legacy "$fc" "${legacy[@]}" "$out/fresh/parser/ala02_p.f"
run_status fresh-forward-strict "$fc" "${strict[@]}" "$out/fresh/forward/ala02_d.f"
run_status fresh-forward-legacy "$fc" "${legacy[@]}" "$out/fresh/forward/ala02_d.f"
run_status fresh-reverse-strict "$fc" "${strict[@]}" "$out/fresh/reverse/ala02_b.f"
run_status fresh-reverse-legacy "$fc" "${legacy[@]}" "$out/fresh/reverse/ala02_b.f"
test "$(status fresh-parser-strict)" -eq 0
test "$(status fresh-parser-legacy)" -eq 0
test "$(status fresh-forward-strict)" -eq 0
test "$(status fresh-forward-legacy)" -eq 0
test "$(status fresh-reverse-strict)" -ne 0
test "$(status fresh-reverse-legacy)" -eq 0

normalize_message() {
    sed -E '/Command: Took subroutine root as default differentiation root/d; s/^[0-9]+[[:space:]]*//' "$1"
}
normalize_message "$source_dir/program_p.msg" >"$out/stored-p.msg.normalized"
normalize_message "$source_dir/program_d.msg" >"$out/stored-d.msg.normalized"
normalize_message "$source_dir/program_b.msg" >"$out/stored-b.msg.normalized"
normalize_message "$out/fresh/parser/ala02_p.msg" >"$out/fresh-p.msg.normalized"
normalize_message "$out/fresh/forward/ala02_d.msg" >"$out/fresh-d.msg.normalized"
normalize_message "$out/fresh/reverse/ala02_b.msg" >"$out/fresh-b.msg.normalized"
cmp -s "$out/stored-p.msg.normalized" "$out/fresh-p.msg.normalized"
cmp -s "$out/stored-d.msg.normalized" "$out/fresh-d.msg.normalized"
cmp -s "$out/stored-b.msg.normalized" "$out/fresh-b.msg.normalized"

run_status fortad-check "$fortad" check --proc root --output "$out/check.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --indep x --dep y --proc root \
    --name ala02_forward --module ala02_forward_mod --output "$out/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --indep x --dep y --proc root \
    --name ala02_reverse --module ala02_reverse_mod --output "$out/reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do
    test "$(status "fortad-$mode")" -ne 0
    grep -Fq "unsupported statement at line 39" "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    test ! -e "$out/$mode.f90"
done

run_status fortad-compat-parser "$fortad" -p -root root -O "$out/compat/parser" -o ala02 "$source_dir/program.f"
run_status fortad-compat-forward "$fortad" -d -root root -O "$out/compat/forward" -o ala02 "$source_dir/program.f"
run_status fortad-compat-reverse "$fortad" -b -root root -O "$out/compat/reverse" -o ala02 "$source_dir/program.f"
for mode in parser forward reverse; do
    test "$(status "fortad-compat-$mode")" -ne 0
    grep -Fq "unsupported statement at line 39" \
        "$out/fortad-compat-$mode.stdout" "$out/fortad-compat-$mode.stderr"
done
test ! -e "$out/compat/parser/ala02_p.f90"
test ! -e "$out/compat/forward/ala02_d.f90"
test ! -e "$out/compat/reverse/ala02_b.f90"

oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions/set01/ala02\n'
    printf 'classification: expected-refusal-fortad-unsupported-print-line-39\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict[*]}"
    printf 'legacy_flags: %s\n' "${legacy[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: root(x,y,initial)\n'
    printf 'tapenade_options: -p; -d -root root; -b -root root; Options=-context -fixinterface -standalonediff\n'
    printf 'strict_compile: exact=%s stored_p=%s stored_d=%s stored_b=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' \
        "$(status exact-strict)" "$(status stored-p-strict)" "$(status stored-d-strict)" "$(status stored-b-strict)" \
        "$(status fresh-parser-strict)" "$(status fresh-forward-strict)" "$(status fresh-reverse-strict)"
    printf 'legacy_compile: exact=%s stored_p=%s stored_d=%s stored_b=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' \
        "$(status exact-legacy)" "$(status stored-p-legacy)" "$(status stored-d-legacy)" "$(status stored-b-legacy)" \
        "$(status fresh-parser-legacy)" "$(status fresh-forward-legacy)" "$(status fresh-reverse-legacy)"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'tapenade_reference_diagnostics: normalized-p-d-b-match-stored\n'
    printf 'fortad_modern_behavior: check=%s forward=%s reverse=%s diagnostic=unsupported-statement-line-39 no-output\n' \
        "$(status fortad-check)" "$(status fortad-forward)" "$(status fortad-reverse)"
    printf 'fortad_compatible_behavior: parser=%s forward=%s reverse=%s diagnostic=unsupported-statement-line-39 no-output\n' \
        "$(status fortad-compat-parser)" "$(status fortad-compat-forward)" "$(status fortad-compat-reverse)"
    printf 'independent_oracle: intended-fixed-point-primal jvp-finite-difference vjp-adjoint-identity\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: exact-source-only\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f \
        "$source_rel"/program_p.f "$source_rel"/program_p.msg "$source_rel"/program_d.f \
        "$source_rel"/program_d.msg "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/ala02_p.f parser/ala02_p.msg forward/ala02_d.f \
        forward/ala02_d.msg reverse/ala02_b.f reverse/ala02_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
