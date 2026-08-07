#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=93f41d60d882778699ec1a887ce9a665a75afcf8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/lh105
source_dir="$tapenade_repo/$source_rel"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-lh105.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
command -v fo >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade"
for source in program.f program_b.f program_b.msg; do
    test -s "$source_dir/$source"
done

strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only
    -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
legacy_fixed=(-std=legacy -ffixed-form -ffixed-line-length-none -fsyntax-only
    -Wall -Wextra -Wimplicit-interface -fno-lto)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -fsyntax-only
    -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
legacy_free=(-std=legacy -ffree-form -ffree-line-length-none -fsyntax-only
    -Wall -Wextra -Wimplicit-interface -fno-lto)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build --cwd "$out/fortad" fortad "$@")
}

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" "$out/fortad"

run_status exact-strict "$fc" "${strict_fixed[@]}" "$source_dir/program.f"
run_status exact-legacy "$fc" "${legacy_fixed[@]}" "$source_dir/program.f"
run_status stored-strict "$fc" "${strict_fixed[@]}" "$source_dir/program_b.f"
run_status stored-legacy "$fc" "${legacy_fixed[@]}" "$source_dir/program_b.f"
test "$(status exact-strict)" -eq 0
test "$(status exact-legacy)" -eq 0
test "$(status stored-strict)" -eq 0
test "$(status stored-legacy)" -eq 0

for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p; extra=() ;;
        forward) flag=-d; suffix=d; extra=(-root top) ;;
        reverse) flag=-b; suffix=b; extra=(-root top) ;;
    esac
    run_status "tapenade-$mode" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$flag' ${extra[*]} -O . -o lh105 '$source_dir/program.f'"
    test "$(status tapenade-$mode)" -eq 0
    test -s "$out/fresh/$mode/lh105_${suffix}.f"
    test -e "$out/fresh/$mode/lh105_${suffix}.msg"
    run_status "fresh-$mode-strict" "$fc" "${strict_fixed[@]}" \
        "$out/fresh/$mode/lh105_${suffix}.f"
    run_status "fresh-$mode-legacy" "$fc" "${legacy_fixed[@]}" \
        "$out/fresh/$mode/lh105_${suffix}.f"
    test "$(status fresh-$mode-strict)" -eq 0
    test "$(status fresh-$mode-legacy)" -eq 0
done

run_status fortad-check fortad_exec check --proc top --output "$out/fortad/check.f90" \
    "$source_dir/program.f"
test "$(status fortad-check)" -eq 0
test -s "$out/fortad/check.f90"
run_status fortad-check-strict "$fc" "${strict_free[@]}" "$out/fortad/check.f90"
run_status fortad-check-legacy "$fc" "${legacy_free[@]}" "$out/fortad/check.f90"
test "$(status fortad-check-strict)" -eq 0
test "$(status fortad-check-legacy)" -eq 0

run_status fortad-forward fortad_exec --mode forward --proc top --indep a,b \
    --name top_jvp --module top_jvp_mod --output "$out/fortad/forward.f90" \
    "$source_dir/program.f"
test "$(status fortad-forward)" -eq 0
test -s "$out/fortad/forward.f90"
run_status fortad-forward-strict "$fc" "${strict_free[@]}" "$out/fortad/forward.f90"
run_status fortad-forward-legacy "$fc" "${legacy_free[@]}" "$out/fortad/forward.f90"
test "$(status fortad-forward-strict)" -eq 0
test "$(status fortad-forward-legacy)" -eq 0

run_status fortad-reverse fortad_exec --mode reverse --proc top --indep a,b --dep a \
    --name top_vjp --module top_vjp_mod --output "$out/fortad/reverse.f90" \
    "$source_dir/program.f"
test "$(status fortad-reverse)" -eq 0
test -s "$out/fortad/reverse.f90"
run_status fortad-reverse-strict "$fc" "${strict_free[@]}" "$out/fortad/reverse.f90"
run_status fortad-reverse-legacy "$fc" "${legacy_free[@]}" "$out/fortad/reverse.f90"
test "$(status fortad-reverse-strict)" -ne 0
test "$(status fortad-reverse-legacy)" -ne 0
for diagnostic in fortad-reverse-strict fortad-reverse-legacy; do
    grep -Fqi "duplicate symbol" "$out/$diagnostic.stdout" "$out/$diagnostic.stderr"
    grep -Fqi "a_b" "$out/$diagnostic.stdout" "$out/$diagnostic.stderr"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions/set01/lh105\n'
    printf 'classification: expected-refusal-fortad-reverse-inout-adjoint-collision\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'legacy_free_flags: %s\n' "${legacy_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: top(a,b,i)\n'
    printf 'tapenade_options: parser=-p forward=-d/-root top reverse=-b/-root top\n'
    printf 'strict_compile: exact=%s stored_reverse=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' \
        "$(status exact-strict)" "$(status stored-strict)" "$(status fresh-parser-strict)" \
        "$(status fresh-forward-strict)" "$(status fresh-reverse-strict)"
    printf 'legacy_compile: exact=%s stored_reverse=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s\n' \
        "$(status exact-legacy)" "$(status stored-legacy)" "$(status fresh-parser-legacy)" \
        "$(status fresh-forward-legacy)" "$(status fresh-reverse-legacy)"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'fortad_exact_behavior: check=pass forward=pass reverse=generated-but-expected-refusal-at-strict-and-legacy-compile-duplicate-a_b\n'
    printf 'fortad_check_compile: strict=%s legacy=%s\n' \
        "$(status fortad-check-strict)" "$(status fortad-check-legacy)"
    printf 'fortad_forward_compile: strict=%s legacy=%s\n' \
        "$(status fortad-forward-strict)" "$(status fortad-forward-legacy)"
    printf 'fortad_reverse_compile: strict=expected-refusal-status-%s legacy=expected-refusal-status-%s diagnostic=duplicate-symbol-a_b\n' \
        "$(status fortad-reverse-strict)" "$(status fortad-reverse-legacy)"
    printf 'independent_oracle: exact-operation-inventory jvp-central-difference vjp-adjoint-identity\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: exact-source-preserved\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_b.f program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/lh105_p.f parser/lh105_p.msg \
        forward/lh105_d.f forward/lh105_d.msg reverse/lh105_b.f reverse/lh105_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
