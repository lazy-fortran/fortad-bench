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
source_rel=nonRegressions/set01/lh109
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh109.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$fortad_repo" branch --show-current)" = main
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad" && test -x "$tapenade"
for source in program.f program_b.f program_b.msg; do test -s "$source_dir/$source"; done

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only -fno-lto)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface -fsyntax-only -fno-lto)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" "$out/fortad"

run_status exact-strict "$fc" "${strict[@]}" "$source_dir/program.f"
run_status stored-strict "$fc" "${strict[@]}" "$source_dir/program_b.f"
run_status exact-legacy "$fc" "${legacy[@]}" "$source_dir/program.f"
run_status stored-legacy "$fc" "${legacy[@]}" "$source_dir/program_b.f"
test "$(status exact-strict)" -eq 0
test "$(status stored-strict)" -eq 0
test "$(status exact-legacy)" -eq 0
test "$(status stored-legacy)" -eq 0

for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p ;;
        forward) flag=-d; suffix=d ;;
        reverse) flag=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$flag' -root adj3 -O . -o lh109 '$source_dir/program.f'"
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$out/fresh/$mode/lh109_${suffix}.f"
    test -s "$out/fresh/$mode/lh109_${suffix}.msg"
    run_status "fresh-$mode-strict" "$fc" "${strict[@]}" \
        "$out/fresh/$mode/lh109_${suffix}.f"
    run_status "fresh-$mode-legacy" "$fc" "${legacy[@]}" \
        "$out/fresh/$mode/lh109_${suffix}.f"
    test "$(status "fresh-$mode-strict")" -eq 0
    test "$(status "fresh-$mode-legacy")" -eq 0
done

diff -I '^C  Tapenade ' "$source_dir/program_b.f" \
    "$out/fresh/reverse/lh109_b.f" >/dev/null
sed -E '/Command: Took subroutine adj3 as default differentiation root/d; s/^[0-9]+ //' \
    "$source_dir/program_b.msg" >"$out/stored.msg.normalized"
sed -E '/Command: Took subroutine adj3 as default differentiation root/d; s/^[0-9]+ //' \
    "$out/fresh/reverse/lh109_b.msg" >"$out/fresh.msg.normalized"
cmp "$out/stored.msg.normalized" "$out/fresh.msg.normalized"

run_status fortad-check "$fortad" check --proc adj3 \
    --output "$out/fortad/check.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --proc adj3 \
    --indep z,t --dep z,t --name adj3_d --module adj3_d_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --proc adj3 \
    --indep z,t --dep z,t --name adj3_b --module adj3_b_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do
    test "$(status "fortad-$mode")" -ne 0
    grep -Fq "unsupported statement at line 6" \
        "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    test ! -e "$out/fortad/$mode.f90"
done

python3 "$case_dir/oracle.py" "$source_dir" >"$out/oracle.txt"
grep -Fq 'oracle_status: pass' "$out/oracle.txt"

{
    printf 'case: Tapenade nonRegressions/set01/lh109\n'
    printf 'classification: expected-refusal-fortad-unsupported-common-line-6\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'upstream_entry_point: adj3(z,t); calls sub1(u,y2,z,v)\n'
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
    printf 'tapenade_reverse_reference: fresh-body-equals-stored-after-banner-normalization diagnostic-content-equal-after-root-and-sequence-normalization\n'
    printf 'fortad_exact_behavior: check=expected-refusal forward=expected-refusal reverse=expected-refusal diagnostic=unsupported-common-line-6 no-output\n'
    printf 'independent_oracle: bounded-sub1-primal jvp-finite-difference vjp-dot-product\n'
    cat "$out/oracle.txt"
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/lh109_p.f parser/lh109_p.msg \
        forward/lh109_d.f forward/lh109_d.msg reverse/lh109_b.f reverse/lh109_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
