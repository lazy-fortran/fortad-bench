#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh090 exact-source boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh090"
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=7adc75030db3fa4422339d82d2725ae29ee13dac
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/lh090
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh090.XXXXXX)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"

for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for message in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -f "$source_dir/$message"
done

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only
    -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_fixed() {
    local label=$1
    local source=$2
    run_status "compile-$label" "$fc" "${strict_flags[@]}" "$source"
}

for source in program program_p program_d program_b; do
    compile_fixed "stored-$source" "$source_dir/$source.f"
    test "$(cat "$out/compile-stored-$source.status")" -eq 0
done
compile_fixed stored-program_dv "$source_dir/program_dv.f"
test "$(cat "$out/compile-stored-program_dv.status")" -ne 0
grep -Fqi "Cannot open included file" "$out/compile-stored-program_dv.stderr"

run_status tapenade-parser "$tapenade" -p -O "$out/fresh/parser" -o lh090 \
    "$source_dir/program.f"
run_status tapenade-forward "$tapenade" -d -root testInitAdj -O "$out/fresh/forward" \
    -o lh090 "$source_dir/program.f"
run_status tapenade-reverse "$tapenade" -b -root testInitAdj -O "$out/fresh/reverse" \
    -o lh090 "$source_dir/program.f"

for mode in parser forward reverse; do
    case "$mode" in
        parser) suffix=p ;;
        forward) suffix=d ;;
        reverse) suffix=b ;;
    esac
    generated="$out/fresh/$mode/lh090_${suffix}.f"
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
    test -s "$generated"
    compile_fixed "fresh-$mode" "$generated"
    test "$(cat "$out/compile-fresh-$mode.status")" -eq 0
done

run_status fortad-check "$fortad" check --output "$out/fortad-check.f90" \
    "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --indep x --dep y \
    --proc testInitAdj --name lh090_jvp --module lh090_jvp_mod \
    --output "$out/fortad-forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --indep x --dep y \
    --proc testInitAdj --name lh090_vjp --module lh090_vjp_mod \
    --output "$out/fortad-reverse.f90" "$source_dir/program.f"

for mode in check forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    grep -Fq "unsupported statement at line 11" "$out/fortad-$mode.stdout" \
        "$out/fortad-$mode.stderr"
done
test ! -e "$out/fortad-check.f90"
test ! -e "$out/fortad-forward.f90"
test ! -e "$out/fortad-reverse.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set01 lh090\n'
    printf 'classification: expected-refusal-fortad-unsupported-legacy-goto\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: testInitAdj(x,y)\n'
    printf 'selected_entry_points: testInitAdj\n'
    printf 'tapenade_options: parser=-p forward=-d/-root testInitAdj reverse=-b/-root testInitAdj\n'
    printf 'stored_strict_compile: program=pass parser=pass forward=pass reverse=pass multidirectional=expected-refusal-missing-DIFFSIZES.inc\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-forward.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/compile-fresh-parser.status")" "$(cat "$out/compile-fresh-forward.status")" \
        "$(cat "$out/compile-fresh-reverse.status")"
    printf 'fortad_exact_behavior: check=expected-refusal forward=expected-refusal reverse=expected-refusal diagnostic=unsupported-statement-line-11 no-output\n'
    printf 'independent_oracle: finite-prefix-control-flow tangent-finite-difference reverse-dot-product\n'
    printf '%s\n' "$oracle_output"
    printf 'no_bounded_numerical_port: positive-input-loop-does-not-terminate\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum lh090_p.f lh090_p.msg)
    (cd "$out/fresh/forward" && sha256sum lh090_d.f lh090_d.msg)
    (cd "$out/fresh/reverse" && sha256sum lh090_b.f lh090_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh090/manifest.toml \
        cases/tapenade-set01/lh090/notes.md cases/tapenade-set01/lh090/oracle.py \
        cases/tapenade-set01/lh090/run.sh cases/tapenade-set01/lh090/test_contract.py)
} >"$result"
cat "$result"
