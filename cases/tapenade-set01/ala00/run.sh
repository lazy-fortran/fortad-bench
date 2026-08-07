#!/usr/bin/env bash
# Validate the pinned Tapenade set01/ala00 exact-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=8137837b6c474708c20ea86ad02b086aa15322fd
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/ala00
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-ala00.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse --abbrev-ref HEAD)" = main
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"

for source in Options program.f program_p.f program_p.msg program_d.f program_d.msg program_b.f program_b.msg; do
    test -e "$source_dir/$source"
done

strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy_fixed=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra
    -Wimplicit-interface -fno-lto -fsyntax-only)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_fixed() {
    local label=$1
    local flags=$2
    local source=$3
    # shellcheck disable=SC2086
    run_status "$label" "$fc" $flags "$source"
}

for file in program.f program_p.f program_d.f program_b.f; do
    label=${file%.f}
    compile_fixed "$label-strict" "${strict_fixed[*]}" "$source_dir/$file"
    compile_fixed "$label-legacy" "${legacy_fixed[*]}" "$source_dir/$file"
done
for label in program program_p program_d; do
    test "$(cat "$out/$label-strict.status")" -eq 0
    test "$(cat "$out/$label-legacy.status")" -eq 0
done
test "$(cat "$out/program_b-strict.status")" -ne 0
grep -Fq "REAL*8" "$out/program_b-strict.stderr"
test "$(cat "$out/program_b-legacy.status")" -eq 0

for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p ;;
        forward) flag=-d; suffix=d ;;
        reverse) flag=-b; suffix=b ;;
    esac
    mkdir -p "$out/fresh/$mode"
    run_status "tapenade-$mode" "$tapenade" "$flag" -root root \
        -O "$out/fresh/$mode" -o ala00 "$source_dir/program.f"
    generated="$out/fresh/$mode/ala00_$suffix.f"
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
    test -s "$generated"
    compile_fixed "fresh-$mode-strict" "${strict_fixed[*]}" "$generated"
    compile_fixed "fresh-$mode-legacy" "${legacy_fixed[*]}" "$generated"
done
for mode in parser forward; do
    test "$(cat "$out/fresh-$mode-strict.status")" -eq 0
    test "$(cat "$out/fresh-$mode-legacy.status")" -eq 0
done
test "$(cat "$out/fresh-reverse-strict.status")" -ne 0
grep -Fq "REAL*8" "$out/fresh-reverse-strict.stderr"
test "$(cat "$out/fresh-reverse-legacy.status")" -eq 0

run_status fortad-check "$fortad" check --proc root --output "$out/fortad-check.f90" \
    "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --proc root --indep x,initial --dep y \
    --name ala00_d --module ala00_d_mod --output "$out/fortad-forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --proc root --indep x,initial --dep y \
    --name ala00_b --module ala00_b_mod --output "$out/fortad-reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    grep -Fq "unsupported statement at line 39" "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    test ! -e "$out/fortad-$mode.f90"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set01 ala00\n'
    printf 'classification: expected-refusal-fortad-unsupported-print-and-reverse-real8\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy_fixed[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: root(x,y,initial)\n'
    printf 'tapenade_options: parser=-p/-root root forward=-d/-root root reverse=-b/-root root\n'
    printf 'exact_compilation: program.f=strict-pass-legacy-pass program_p.f=strict-pass-legacy-pass program_d.f=strict-pass-legacy-pass program_b.f=strict-refusal-REAL8-legacy-pass\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-forward.status")" "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-strict.status")" "$(cat "$out/fresh-forward-strict.status")" "$(cat "$out/fresh-reverse-strict.status")"
    printf 'tapenade_fresh_legacy_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-legacy.status")" "$(cat "$out/fresh-forward-legacy.status")" "$(cat "$out/fresh-reverse-legacy.status")"
    printf 'fortad_exact_behavior: check=expected-refusal forward=expected-refusal reverse=expected-refusal diagnostic=unsupported-statement-line-39 no-output\n'
    printf 'independent_oracle: exact-source-shape fixed-point-map hand-JVP central-difference hand-VJP dot-product\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: true\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f "$source_rel"/program_p.f "$source_rel"/program_p.msg "$source_rel"/program_d.f "$source_rel"/program_d.msg "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/ala00_p.f parser/ala00_p.msg forward/ala00_d.f forward/ala00_d.msg reverse/ala00_b.f reverse/ala00_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
