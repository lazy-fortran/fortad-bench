#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../../.." && pwd)
main_root=$(git -C "$bench_root" worktree list --porcelain | awk 'NR == 1 {print $2}')
default_fortad=$(dirname "$main_root")/fortad
default_tapenade="$main_root/upstream/tapenade"
fortad_repo=$(cd "${FORTAD_REPO:-$default_fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$default_tapenade}" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
result="$case_dir/result.txt"
source_rel=nonRegressions/set02/lh196
source_dir="$tapenade_repo/$source_rel"
required_fortad_commit=ac8d04be7303bbd3b6bd9f865074401b5041b9af
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set02-lh196.XXXXXX)
trap 'rm -rf "$out"' EXIT

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)

for tool in "$fc" java python3 fo; do command -v "$tool" >/dev/null; done
test -x "$fortad"
test -x "$tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in Options program.f program_b.f program_b.msg program_d.f program_d.msg; do
    test -e "$source_dir/$source"
done

run_capture() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_capture() {
    local label=$1 source=$2 flavor=$3
    if test "$flavor" = strict; then
        run_capture "$label" "$fc" "${strict[@]}" "$source"
    else
        run_capture "$label" "$fc" "${legacy[@]}" "$source"
    fi
}

status() { cat "$out/$1.status"; }

for source in program.f program_b.f program_d.f; do
    stem=${source%.f}
    compile_capture "exact-strict-$stem" "$source_dir/$source" strict
    compile_capture "exact-legacy-$stem" "$source_dir/$source" legacy
    test "$(status "exact-strict-$stem")" -ne 0
    grep -Fq 'REAL*8' "$out/exact-strict-$stem.stderr"
    test "$(status "exact-legacy-$stem")" -eq 0
done

run_capture exact-primal-build "$fc" -std=legacy -ffixed-form -ffixed-line-length-none \
    -Wall -Wextra -Wimplicit-interface -fno-lto "$source_dir/program.f" \
    -o "$out/exact-primal"
test "$(status exact-primal-build)" -eq 0
run_capture exact-primal-run "$out/exact-primal"
test "$(status exact-primal-run)" -eq 0

mkdir -p "$out/fresh/parser" "$out/fresh/tangent" "$out/fresh/reverse"
for mode_spec in "parser -p p" "tangent -d d" "reverse -b b"; do
    set -- $mode_spec
    mode=$1
    flag=$2
    suffix=$3
    run_capture "tapenade-$mode" bash -c \
        "cd '$source_dir' && '$tapenade' '$flag' -head 'polycost(polycost)/(X Y)' -context -debugADJ -O '$out/fresh/$mode' -o lh196 program.f"
    test "$(status "tapenade-$mode")" -eq 0
    generated="$out/fresh/$mode/lh196_${suffix}.f"
    test -s "$generated"
    test -f "$out/fresh/$mode/lh196_${suffix}.msg"
    compile_capture "fresh-strict-$mode" "$generated" strict
    compile_capture "fresh-legacy-$mode" "$generated" legacy
    test "$(status "fresh-strict-$mode")" -ne 0
    grep -Fq 'REAL*8' "$out/fresh-strict-$mode.stderr"
    test "$(status "fresh-legacy-$mode")" -eq 0
done

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

mkdir -p "$out/fortad"
run_capture fortad-check fortad_exec check --proc polycost \
    --output "$out/fortad/check.f90" "$source_dir/program.f"
run_capture fortad-forward fortad_exec --mode forward --proc polycost \
    --indep X,Y --dep POLYCOST --name lh196_jvp --module lh196_jvp_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f"
run_capture fortad-reverse fortad_exec --mode reverse --proc polycost \
    --indep X,Y --dep POLYCOST --name lh196_vjp --module lh196_vjp_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do
    test "$(status "fortad-$mode")" -ne 0
    grep -Fq 'inlining POLYPERIM would need a statement form it does not have' \
        "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    test ! -e "$out/fortad/$mode.f90"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions/set02/lh196 POLYCOST(X,Y,ns)\n'
    printf 'classification: expected-refusal-fortad-function-inlining-real8-boundary\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'entry_point: POLYCOST(X,Y,ns)\n'
    printf 'tapenade_options: parser=-p tangent=-d reverse=-b; -head polycost(polycost)/(X Y) -context -debugADJ\n'
    printf 'upstream_exact_strict_compile: program=%s program_b=%s program_d=%s diagnostic=REAL8\n' \
        "$(status exact-strict-program)" "$(status exact-strict-program_b)" "$(status exact-strict-program_d)"
    printf 'upstream_exact_legacy_compile: program=%s program_b=%s program_d=%s\n' \
        "$(status exact-legacy-program)" "$(status exact-legacy-program_b)" "$(status exact-legacy-program_d)"
    printf 'exact_primal_runtime: build=%s run=%s output=%s\n' \
        "$(status exact-primal-build)" "$(status exact-primal-run)" \
        "$(tr '\n' ' ' <"$out/exact-primal-run.stdout" | sed 's/[[:space:]]*$//')"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(status tapenade-parser)" "$(status tapenade-tangent)" "$(status tapenade-reverse)"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s diagnostic=REAL8\n' \
        "$(status fresh-strict-parser)" "$(status fresh-strict-tangent)" "$(status fresh-strict-reverse)"
    printf 'tapenade_fresh_legacy_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(status fresh-legacy-parser)" "$(status fresh-legacy-tangent)" "$(status fresh-legacy-reverse)"
    printf 'fortad_exact_behavior: check=expected-refusal status=%s forward=expected-refusal status=%s reverse=expected-refusal status=%s diagnostic="inlining POLYPERIM would need a statement form it does not have" no-output\n' \
        "$(status fortad-check)" "$(status fortad-forward)" "$(status fortad-reverse)"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: polygon-cost primal, closed-form JVP/VJP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: true\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f \
        "$source_rel"/program_b.f "$source_rel"/program_b.msg \
        "$source_rel"/program_d.f "$source_rel"/program_d.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/lh196_p.f parser/lh196_p.msg \
        tangent/lh196_d.f tangent/lh196_d.msg reverse/lh196_b.f reverse/lh196_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
    printf 'closure: exact-source expected refusal; strict REAL8 boundary and unsupported POLYPERIM inlining; no repaired source or support claim\n'
} >"$result"
cat "$result"
