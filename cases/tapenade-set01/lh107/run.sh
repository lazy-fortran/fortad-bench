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
source_rel=nonRegressions/set01/lh107
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-lh107.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
fortad_status=$(git -C "$fortad_repo" status --porcelain --untracked-files=all)
test -z "$(printf '%s\n' "$fortad_status" | awk 'NF && substr($0, 4) != "ROADMAP.md" {print}')"
if [[ -n "$fortad_status" ]]; then
    fortad_worktree_record=${fortad_status//$'\n'/'; '}
else
    fortad_worktree_record=clean
fi
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad" && test -x "$tapenade"
for source in program.f program_b.f program_b.msg; do test -s "$source_dir/$source"; done

strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only)
legacy_fixed=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface -fsyntax-only)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
run_status exact-strict "$fc" "${strict_fixed[@]}" "$source_dir/program.f"
run_status exact-legacy "$fc" "${legacy_fixed[@]}" "$source_dir/program.f"
run_status stored-strict "$fc" "${strict_fixed[@]}" "$source_dir/program_b.f"
run_status stored-legacy "$fc" "${legacy_fixed[@]}" "$source_dir/program_b.f"
test "$(status exact-strict)" -eq 0
test "$(status exact-legacy)" -eq 0
test "$(status stored-strict)" -ne 0
test "$(status stored-legacy)" -eq 0

for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p; extra=();;
        forward) flag=-d; suffix=d; extra=(-root test);;
        reverse) flag=-b; suffix=b; extra=(-root test);;
    esac
    run_status "tapenade-$mode" "$tapenade" "$flag" "${extra[@]}" -O "$out/fresh/$mode" -o lh107 "$source_dir/program.f"
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$out/fresh/$mode/lh107_${suffix}.f"
    test -s "$out/fresh/$mode/lh107_${suffix}.msg"
done
grep -Fq "TC32" "$out/fresh/parser/lh107_p.msg"
grep -Fq "AD09" "$out/fresh/forward/lh107_d.msg"
grep -Fq "AD09" "$out/fresh/reverse/lh107_b.msg"

run_status fresh-parser-strict "$fc" "${strict_fixed[@]}" "$out/fresh/parser/lh107_p.f"
run_status fresh-parser-legacy "$fc" "${legacy_fixed[@]}" "$out/fresh/parser/lh107_p.f"
run_status fresh-forward-strict "$fc" "${strict_fixed[@]}" "$out/fresh/forward/lh107_d.f"
run_status fresh-forward-legacy "$fc" "${legacy_fixed[@]}" "$out/fresh/forward/lh107_d.f"
run_status fresh-reverse-strict "$fc" "${strict_fixed[@]}" "$out/fresh/reverse/lh107_b.f"
run_status fresh-reverse-legacy "$fc" "${legacy_fixed[@]}" "$out/fresh/reverse/lh107_b.f"
test "$(status fresh-parser-strict)" -eq 0
test "$(status fresh-parser-legacy)" -eq 0
test "$(status fresh-forward-strict)" -ne 0
test "$(status fresh-forward-legacy)" -ne 0
test "$(status fresh-reverse-strict)" -ne 0
test "$(status fresh-reverse-legacy)" -eq 0

mkdir -p "$out/fortad/parser" "$out/fortad/forward" "$out/fortad/reverse"
run_status fortad-check "$fortad" check --proc test --output "$out/fortad/check.f90" "$source_dir/program.f"
run_status fortad-parser "$fortad" -p -root test -O "$out/fortad/parser" -o lh107 "$source_dir/program.f"
run_status fortad-forward "$fortad" -d -root test -O "$out/fortad/forward" -o lh107 "$source_dir/program.f"
run_status fortad-reverse "$fortad" -b -root test -O "$out/fortad/reverse" -o lh107 "$source_dir/program.f"
test "$(status fortad-check)" -eq 0
test "$(status fortad-parser)" -eq 0
test "$(status fortad-forward)" -eq 0
test "$(status fortad-reverse)" -eq 0
test -s "$out/fortad/check.f90"
for mode in parser forward reverse; do
    case "$mode" in parser) suffix=p;; forward) suffix=d;; reverse) suffix=b;; esac
    test -s "$out/fortad/$mode/lh107_${suffix}.f90"
    run_status "fortad-$mode-strict" "$fc" "${strict_free[@]}" "$out/fortad/$mode/lh107_${suffix}.f90"
    test "$(status "fortad-$mode-strict")" -eq 0
done
run_status fortad-check-strict "$fc" "${strict_free[@]}" "$out/fortad/check.f90"
test "$(status fortad-check-strict)" -eq 0

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions/set01/lh107\n'
    printf 'classification: runnable-upstream-fortad-multi-argument-max\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'fortad_commit: %s\nrequired_fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)" "$required_fortad_commit"
    printf 'tapenade_commit: %s\nrequired_tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)" "$required_tapenade_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree_record"
    printf 'upstream_entry_point: test(a,b)\n'
    printf 'strict_compile: exact=%s stored_reverse=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s fortad_check=%s fortad_parser=%s fortad_forward=%s fortad_reverse=%s\n' \
        "$(status exact-strict)" "$(status stored-strict)" "$(status fresh-parser-strict)" "$(status fresh-forward-strict)" "$(status fresh-reverse-strict)" "$(status fortad-check-strict)" "$(status fortad-parser-strict)" "$(status fortad-forward-strict)" "$(status fortad-reverse-strict)"
    printf 'legacy_compile: exact=%s stored_reverse=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' \
        "$(status exact-legacy)" "$(status stored-legacy)" "$(status fresh-parser-legacy)" "$(status fresh-forward-legacy)" "$(status fresh-reverse-legacy)"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'fortad_exact_behavior: check=pass parser=pass forward=pass reverse=pass all_direct_products_strict_compile\n'
    printf 'independent_oracle: source-inventory max-sequence-jvp-finite-difference vjp-adjoint-identity\n%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/lh107_p.f parser/lh107_p.msg forward/lh107_d.f forward/lh107_d.msg reverse/lh107_b.f reverse/lh107_b.msg)
    printf 'fortad_output_sha256:\n'
    (cd "$out/fortad" && sha256sum check.f90 parser/lh107_p.f90 forward/lh107_d.f90 reverse/lh107_b.f90)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
