#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set01/lh084 fixed-form boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=7adc75030db3fa4422339d82d2725ae29ee13dac
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/lh084
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-lh084.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"; test -x "$tapenade"
for source in program.f program_b.f program_b.msg; do test -e "$source_dir/$source"; done

strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fsyntax-only)
legacy_flags=(-std=legacy -ffixed-form -ffixed-line-length-none
    -Wall -Wextra -Wimplicit-interface -fsyntax-only)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

run_status strict_primal "$fc" "${strict_flags[@]}" "$source_dir/program.f"
run_status strict_reverse "$fc" "${strict_flags[@]}" "$source_dir/program_b.f"
test "$(cat "$out/strict_primal.status")" -ne 0
test "$(cat "$out/strict_reverse.status")" -ne 0
grep -Fq "GNU Extension: Nonstandard type declaration REAL*8" "$out/strict_primal.stderr"
grep -Fq "GNU Extension: Nonstandard type declaration REAL*8" "$out/strict_reverse.stderr"
run_status legacy_primal "$fc" "${legacy_flags[@]}" "$source_dir/program.f"
run_status legacy_reverse "$fc" "${legacy_flags[@]}" "$source_dir/program_b.f"
test "$(cat "$out/legacy_primal.status")" -eq 0
test "$(cat "$out/legacy_reverse.status")" -eq 0

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -O . -o lh084 '$source_dir/program.f'"
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
    test -e "$out/fresh/$mode/lh084_${suffix}.msg"
    test -e "$out/fresh/$mode/lh084_${suffix}.f"
done
for mode in parser forward reverse; do
    case "$mode" in
        parser) suffix=p ;;
        forward) suffix=d ;;
        reverse) suffix=b ;;
    esac
    run_status "compile-$mode" "$fc" "${legacy_flags[@]}" \
        "$out/fresh/$mode/lh084_${suffix}.f"
    test "$(cat "$out/compile-$mode.status")" -eq 0
done
diff -I '^C  Tapenade ' "$source_dir/program_b.f" "$out/fresh/reverse/lh084_b.f" >/dev/null
cmp "$source_dir/program_b.msg" "$out/fresh/reverse/lh084_b.msg"

for mode in parser forward reverse; do
    case "$mode" in
        parser)
            run_status fortad-parser "$fortad" check --output "$out/fortad-parser.f" "$source_dir/program.f"
            output="$out/fortad-parser.f" ;;
        forward)
            run_status fortad-forward "$fortad" --mode forward --indep t --name lh084_d \
                --module lh084_d_mod --output "$out/fortad-forward.f" "$source_dir/program.f"
            output="$out/fortad-forward.f" ;;
        reverse)
            run_status fortad-reverse "$fortad" --mode reverse --indep t --dep t --name lh084_b \
                --module lh084_b_mod --output "$out/fortad-reverse.f" "$source_dir/program.f"
            output="$out/fortad-reverse.f" ;;
    esac
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$output"
    grep -Fq "could not locate the end of this do construct" "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq 'oracle_status: pass' "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set01/lh084\n'
    printf 'classification: runnable-upstream-exact-source-fortad-refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'legacy_compiler_flags: %s\n' "${legacy_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'source_checkout: %s\n' "$tapenade_repo"
    printf 'upstream_entry_point: flw2d1col\n'
    printf 'selected_entry_points: flw2d1col,check\n'
    printf 'tapenade_options: parser=-p/-O ./-o lh084; forward=-d/-O ./-o lh084; reverse=-b/-O ./-o lh084; default root\n'
    printf 'strict_source_reference: primal=%s reverse=%s diagnostic=expected-legacy-REAL*8\n' "$(cat "$out/strict_primal.status")" "$(cat "$out/strict_reverse.status")"
    printf 'legacy_source_reference: primal=%s reverse=%s\n' "$(cat "$out/legacy_primal.status")" "$(cat "$out/legacy_reverse.status")"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-forward.status")" "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_generated_sources: parser=lh084_p.f forward=lh084_d.f reverse=lh084_b.f\n'
    printf 'tapenade_generated_legacy_compile: parser=%s forward=%s reverse=%s\n' "$(cat "$out/compile-parser.status")" "$(cat "$out/compile-forward.status")" "$(cat "$out/compile-reverse.status")"
    printf 'tapenade_reverse_reference: fresh-body-equals-stored-after-banner-normalization message-byte-equal\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none\n' "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none\n' "$(cat "$out/fortad-reverse.status")"
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-exact-fixed-form-fortad-boundary\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/lh084_p.f parser/lh084_p.msg forward/lh084_d.f forward/lh084_d.msg reverse/lh084_b.f reverse/lh084_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
