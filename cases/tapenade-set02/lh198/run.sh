#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$bench_root/../../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$bench_root/upstream/tapenade}" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
result="$case_dir/result.txt"
source_rel=nonRegressions/set02/lh198
source_dir="$tapenade_repo/$source_rel"
required_fortad_commit=6a33d314c5b1a8adf8b9ed989741612fe09ab6b0
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set02-lh198.XXXXXX)
trap 'rm -rf "$out"' EXIT

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
strict_build=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto)
legacy_build=(-std=legacy -ffixed-form -ffixed-line-length-none
    -Wall -Wextra -Wimplicit-interface -fno-lto)
free_strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)

for tool in "$fc" java python3 fo; do command -v "$tool" >/dev/null; done
test -x "$fortad"
test -x "$tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -f "$tapenade_repo/build/libs/tapenade-3.16.jar"
for source in Options program.f program_b.f program_b.msg program_d.f program_d.msg program_p.f program_p.msg; do
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

for source in program.f program_b.f program_d.f program_p.f; do
    stem=${source%.f}
    compile_capture "exact-strict-$stem" "$source_dir/$source" strict
    compile_capture "exact-legacy-$stem" "$source_dir/$source" legacy
    test "$(status "exact-strict-$stem")" -eq 0
    test "$(status "exact-legacy-$stem")" -eq 0
done

run_capture exact-primal-strict-build "$fc" "${strict_build[@]}" "$source_dir/program.f" -o "$out/exact-primal-strict"
run_capture exact-primal-strict-run "$out/exact-primal-strict"
test "$(status exact-primal-strict-build)" -eq 0
test "$(status exact-primal-strict-run)" -eq 0
run_capture exact-primal-legacy-build "$fc" "${legacy_build[@]}" "$source_dir/program.f" -o "$out/exact-primal-legacy"
run_capture exact-primal-legacy-run "$out/exact-primal-legacy"
test "$(status exact-primal-legacy-build)" -eq 0
test "$(status exact-primal-legacy-run)" -eq 0
grep -Fq 'y=' "$out/exact-primal-strict-run.stdout"
grep -Fq 'y=' "$out/exact-primal-legacy-run.stdout"

mkdir -p "$out/fresh/parser" "$out/fresh/tangent" "$out/fresh/reverse"
for mode_spec in "parser -p p" "tangent -d d" "reverse -b b"; do
    set -- $mode_spec
    mode=$1
    flag=$2
    suffix=$3
    run_capture "tapenade-$mode" bash -c \
        "cd '$source_dir' && '$tapenade' '$flag' -root top -O '$out/fresh/$mode' -o lh198_fresh program.f"
    test "$(status "tapenade-$mode")" -eq 0
    generated="$out/fresh/$mode/lh198_fresh_${suffix}.f"
    test -s "$generated"
    test -f "$out/fresh/$mode/lh198_fresh_${suffix}.msg"
    compile_capture "fresh-strict-$mode" "$generated" strict
    compile_capture "fresh-legacy-$mode" "$generated" legacy
    test "$(status "fresh-strict-$mode")" -eq 0
    test "$(status "fresh-legacy-$mode")" -eq 0
done

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

mkdir -p "$out/fortad"
run_capture fortad-check fortad_exec check --proc top \
    --output "$out/fortad/check.f90" "$source_dir/program.f"
test "$(status fortad-check)" -eq 0
test -s "$out/fortad/check.f90"
run_capture fortad-check-compile "$fc" "${free_strict[@]}" "$out/fortad/check.f90"
test "$(status fortad-check-compile)" -eq 0

run_capture fortad-forward fortad_exec --mode forward --proc top \
    --indep x,y --dep y --name lh198_jvp --module lh198_jvp_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f"
run_capture fortad-reverse fortad_exec --mode reverse --proc top \
    --indep x,y --dep y --name lh198_vjp --module lh198_vjp_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f"
for mode in forward reverse; do
    test "$(status "fortad-$mode")" -ne 0
    if test "$mode" = forward; then
        diagnostic="no derivative rule for the call to 'AAA'"
    else
        diagnostic="no reverse rule for the call to 'AAA'"
    fi
    grep -Fq "$diagnostic" \
        "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    if [[ -s "$out/fortad/$mode.f90" ]]; then
        echo "FortAD emitted non-empty output on $mode refusal" >&2
        exit 1
    else
        :
    fi
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions/set02/lh198 top(x,y) COMMON numbering\n'
    printf 'classification: expected-refusal-fortad-common-block-call-boundary\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'entry_point: top(x,y)\n'
    printf 'tapenade_options: parser=-p tangent=-d reverse=-b -root top; Options=-context -nooptim stripPrimalCode\n'
    printf 'upstream_exact_strict_compile: program=%s program_b=%s program_d=%s program_p=%s\n' \
        "$(status exact-strict-program)" "$(status exact-strict-program_b)" \
        "$(status exact-strict-program_d)" "$(status exact-strict-program_p)"
    printf 'upstream_exact_legacy_compile: program=%s program_b=%s program_d=%s program_p=%s\n' \
        "$(status exact-legacy-program)" "$(status exact-legacy-program_b)" \
        "$(status exact-legacy-program_d)" "$(status exact-legacy-program_p)"
    printf 'exact_primal_runtime: strict_build=%s strict_run=%s legacy_build=%s legacy_run=%s strict_output="%s" legacy_output="%s"\n' \
        "$(status exact-primal-strict-build)" "$(status exact-primal-strict-run)" \
        "$(status exact-primal-legacy-build)" "$(status exact-primal-legacy-run)" \
        "$(tr '\n' ' ' <"$out/exact-primal-strict-run.stdout" | sed 's/[[:space:]]*$//')" \
        "$(tr '\n' ' ' <"$out/exact-primal-legacy-run.stdout" | sed 's/[[:space:]]*$//')"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(status tapenade-parser)" "$(status tapenade-tangent)" "$(status tapenade-reverse)"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(status fresh-strict-parser)" "$(status fresh-strict-tangent)" "$(status fresh-strict-reverse)"
    printf 'tapenade_fresh_legacy_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(status fresh-legacy-parser)" "$(status fresh-legacy-tangent)" "$(status fresh-legacy-reverse)"
    printf 'fortad_exact_behavior: check=pass status=%s output_compile=%s forward=expected-refusal status=%s diagnostic="no derivative rule for the call to AAA" reverse=expected-refusal status=%s diagnostic="no reverse rule for the call to AAA" no-output\n' \
        "$(status fortad-check)" "$(status fortad-check-compile)" \
        "$(status fortad-forward)" "$(status fortad-reverse)"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: COMMON-block primal, hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: true\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f \
        "$source_rel"/program_b.f "$source_rel"/program_b.msg \
        "$source_rel"/program_d.f "$source_rel"/program_d.msg \
        "$source_rel"/program_p.f "$source_rel"/program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/lh198_fresh_p.f parser/lh198_fresh_p.msg \
        tangent/lh198_fresh_d.f tangent/lh198_fresh_d.msg \
        reverse/lh198_fresh_b.f reverse/lh198_fresh_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
    printf 'closure: valid exact source and fresh Tapenade products; current FortAD check passes but forward/reverse deliberately refuse the AAA call; no repaired source or support claim\n'
} >"$result"
cat "$result"
