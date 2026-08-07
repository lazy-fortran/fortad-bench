#!/usr/bin/env bash
# Validate the pinned Tapenade set01/ht03 exact-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=93f41d60d882778699ec1a887ce9a665a75afcf8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/ht03
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-ht03.XXXXXX)
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

for source in program.f program_b.f program_b.msg; do
    test -s "$source_dir/$source"
done

strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy_fixed=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra
    -Wimplicit-interface -fno-lto -fsyntax-only)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy_free=(-std=legacy -ffree-form -ffree-line-length-none -Wall -Wextra
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

compile_fixed exact-strict "${strict_fixed[*]}" "$source_dir/program.f"
compile_fixed exact-legacy "${legacy_fixed[*]}" "$source_dir/program.f"
compile_fixed stored-reverse-strict "${strict_fixed[*]}" "$source_dir/program_b.f"
compile_fixed stored-reverse-legacy "${legacy_fixed[*]}" "$source_dir/program_b.f"
for label in exact-strict exact-legacy stored-reverse-strict stored-reverse-legacy; do
    test "$(cat "$out/$label.status")" -eq 0
done

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
(cd "$tapenade_repo" && run_status tapenade-parser "$tapenade" -p \
    -O "$out/fresh/parser" -o ht03 "$source_dir/program.f")
(cd "$tapenade_repo" && run_status tapenade-forward "$tapenade" -d -root top \
    -O "$out/fresh/forward" -o ht03 "$source_dir/program.f")
(cd "$tapenade_repo" && run_status tapenade-reverse "$tapenade" -b -root top \
    -O "$out/fresh/reverse" -o ht03 "$source_dir/program.f")

for mode in parser forward reverse; do
    case "$mode" in
        parser) suffix=p ;;
        forward) suffix=d ;;
        reverse) suffix=b ;;
    esac
    generated="$out/fresh/$mode/ht03_${suffix}.f"
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
    test -s "$generated"
    compile_fixed "fresh-$mode-strict" "${strict_fixed[*]}" "$generated"
    compile_fixed "fresh-$mode-legacy" "${legacy_fixed[*]}" "$generated"
    test "$(cat "$out/fresh-$mode-strict.status")" -eq 0
    test "$(cat "$out/fresh-$mode-legacy.status")" -eq 0
done

run_status fortad-check "$fortad" check --output "$out/fortad-check.f90" \
    "$source_dir/program.f"
test "$(cat "$out/fortad-check.status")" -eq 0
test -s "$out/fortad-check.f90"
compile_fixed fortad-check-strict "${strict_free[*]}" "$out/fortad-check.f90"
compile_fixed fortad-check-legacy "${legacy_free[*]}" "$out/fortad-check.f90"
test "$(cat "$out/fortad-check-strict.status")" -eq 0
test "$(cat "$out/fortad-check-legacy.status")" -eq 0

run_status fortad-forward-top "$fortad" --mode forward --indep i1,i2,i3 \
    --proc top --name ht03_jvp --module ht03_jvp_mod \
    --output "$out/fortad-forward-top.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-forward-top.status")" -ne 0
grep -Fq "no derivative rule for the call to 'sub1'" \
    "$out/fortad-forward-top.stdout" "$out/fortad-forward-top.stderr"
test ! -e "$out/fortad-forward-top.f90"

run_status fortad-reverse-top "$fortad" --mode reverse --indep i1,i2,i3 \
    --dep o1 --proc top --name ht03_vjp --module ht03_vjp_mod \
    --output "$out/fortad-reverse-top.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-reverse-top.status")" -ne 0
grep -Fq "no reverse rule for the call to 'sub1'" \
    "$out/fortad-reverse-top.stdout" "$out/fortad-reverse-top.stderr"
test ! -e "$out/fortad-reverse-top.f90"

run_status fortad-forward-sub1 "$fortad" --mode forward --indep i1,i2 \
    --proc sub1 --name ht03_sub1_jvp --module ht03_sub1_jvp_mod \
    --output "$out/fortad-forward-sub1.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-forward-sub1.status")" -ne 0
grep -Fq "unsupported statement at line 17" \
    "$out/fortad-forward-sub1.stdout" "$out/fortad-forward-sub1.stderr"
test ! -e "$out/fortad-forward-sub1.f90"

run_status fortad-reverse-sub1 "$fortad" --mode reverse --indep i1,i2 \
    --dep o1 --proc sub1 --name ht03_sub1_vjp --module ht03_sub1_vjp_mod \
    --output "$out/fortad-reverse-sub1.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-reverse-sub1.status")" -ne 0
grep -Fq "unsupported statement at line 17" \
    "$out/fortad-reverse-sub1.stdout" "$out/fortad-reverse-sub1.stderr"
test ! -e "$out/fortad-reverse-sub1.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set01 ht03\n'
    printf 'classification: expected-refusal-fortad-external-io-and-call-boundary\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'legacy_free_flags: %s\n' "${legacy_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: top(i1,i2,i3,o1,o2,o3); sub1(i1,i2,o1,o2)\n'
    printf 'tapenade_options: parser=-p forward=-d/-root top reverse=-b/-root top\n'
    printf 'exact_compilation: strict=pass legacy=pass\n'
    printf 'stored_reverse_compilation: strict=pass legacy=pass\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-forward.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-strict.status")" "$(cat "$out/fresh-forward-strict.status")" \
        "$(cat "$out/fresh-reverse-strict.status")"
    printf 'tapenade_fresh_legacy_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-legacy.status")" "$(cat "$out/fresh-forward-legacy.status")" \
        "$(cat "$out/fresh-reverse-legacy.status")"
    printf 'fortad_check: pass strict-free-compile=pass legacy-free-compile=pass\n'
    printf 'fortad_top_forward: expected-refusal diagnostic=no-derivative-rule-sub1 no-output\n'
    printf 'fortad_top_reverse: expected-refusal diagnostic=no-reverse-rule-sub1 no-output\n'
    printf 'fortad_sub1_forward: expected-refusal diagnostic=unsupported-statement-line-17 no-output\n'
    printf 'fortad_sub1_reverse: expected-refusal diagnostic=unsupported-statement-line-17 no-output\n'
    printf 'independent_oracle: source-shape conditional-read-value-model jvp-central-difference vjp-dot-product\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: external-read-value-held-fixed-only-in-independent-oracle\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_b.f program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum ht03_p.f ht03_p.msg)
    (cd "$out/fresh/forward" && sha256sum ht03_d.f ht03_d.msg)
    (cd "$out/fresh/reverse" && sha256sum ht03_b.f ht03_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/ht03/manifest.toml \
        cases/tapenade-set01/ht03/notes.md cases/tapenade-set01/ht03/oracle.py \
        cases/tapenade-set01/ht03/run.sh cases/tapenade-set01/ht03/test_contract.py)
} >"$result"
cat "$result"
