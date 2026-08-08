#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$bench_root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$bench_root/upstream/tapenade}" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
result="$case_dir/result.txt"
source_dir="$tapenade_repo/nonRegressions/set02/v067"
required_fortad_commit=19e8cda7ad71990339f9ed254cc40128fcbff364
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
free_strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)

test -x "$fortad"
test -x "$tapenade"
test -f "$source_dir/program.f"
test -f "$source_dir/program_p.f"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set02-v067.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod" "$out/tapenade" "$out/fortad"

run_capture() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_capture() {
    local label=$1
    local flavor=$2
    local source=$3
    local flags=()
    test "$flavor" = strict && flags=("${strict[@]}") || flags=("${legacy[@]}")
    run_capture "$label" "$fc" "${flags[@]}" -I"$source_dir" "$source"
}

for source in program.f program_p.f; do
    compile_capture "exact-strict-${source%.f}" strict "$source_dir/$source"
    compile_capture "exact-legacy-${source%.f}" legacy "$source_dir/$source"
    test "$(cat "$out/exact-strict-${source%.f}.status")" -eq 0
    test "$(cat "$out/exact-legacy-${source%.f}.status")" -eq 0
done
test -e "$source_dir/program_p.msg"

for mode_spec in "parser -p p" "tangent -d d" "reverse -b b"; do
    set -- $mode_spec
    mode=$1
    option=$2
    run_capture "tapenade-$mode" bash -c \
        "cd '$out/tapenade' && '$tapenade' '$option' -root ADJ_FCN -O . -o v067 '$source_dir/program.f'"
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
    test -s "$out/tapenade/v067_${3}.msg"
    test ! -e "$out/tapenade/v067_${3}.f"
done
grep -Fq 'unit ADJ_FCN: not found' "$out/tapenade/v067_p.msg"
grep -Fq 'No root unit to differentiate' "$out/tapenade/v067_d.msg"
grep -Fq 'No root unit to differentiate' "$out/tapenade/v067_b.msg"

run_capture fortad-parser "$fortad" check --proc ADJ_FCN \
    --output "$out/fortad/parser.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-parser.status")" -eq 0
test -s "$out/fortad/parser.f90"
run_capture fortad-parser-compile "$fc" "${free_strict[@]}" "$out/fortad/parser.f90"
test "$(cat "$out/fortad-parser-compile.status")" -eq 0

run_capture fortad-forward "$fortad" --mode forward --indep Y --dep T \
    --proc ADJ_FCN --name v067_jvp --module tapenade_set02_v067_forward \
    --output "$out/fortad/forward.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-forward.status")" -eq 0
test -s "$out/fortad/forward.f90"
run_capture fortad-forward-compile "$fc" "${free_strict[@]}" "$out/fortad/forward.f90"
test "$(cat "$out/fortad-forward-compile.status")" -eq 0
! grep -Fq 'T_d = Y_d' "$out/fortad/forward.f90"
! grep -Fq 't = y + pi' "$out/fortad/forward.f90"

run_capture fortad-reverse "$fortad" --mode reverse --indep Y --dep T \
    --proc ADJ_FCN --name v067_vjp --module tapenade_set02_v067_reverse \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-reverse.status")" -ne 0
test ! -e "$out/fortad/reverse.f90"
grep -Fq "assignment to undeclared 't'" "$out/fortad-reverse.stderr"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions/set02/v067 ADJ_FCN(T,Y,YP,RESULT,RP)\n'
    printf 'classification: expected-refusal-valid-source-tapenade-and-fortad-boundary\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'entry_point: ADJ_FCN(T,Y,YP,RESULT,RP)\n'
    printf 'upstream_exact_strict_compile: program.f=%s program_p.f=%s\n' \
        "$(cat "$out/exact-strict-program.status")" "$(cat "$out/exact-strict-program_p.status")"
    printf 'upstream_exact_legacy_compile: program.f=%s program_p.f=%s\n' \
        "$(cat "$out/exact-legacy-program.status")" "$(cat "$out/exact-legacy-program_p.status")"
    printf 'tapenade_exact_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-tangent.status")" "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_exact_products: parser=none tangent=none reverse=none\n'
    printf 'tapenade_exact_diagnostic: CR-only-program.f reports unit ADJ_FCN not found; tangent/reverse report no root unit\n'
    printf 'fortad_exact_parser: pass status=%s strict-free-compile=%s\n' \
        "$(cat "$out/fortad-parser.status")" "$(cat "$out/fortad-parser-compile.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=empty-stub strict-free-compile=%s\n' \
        "$(cat "$out/fortad-forward.status")" "$(cat "$out/fortad-forward-compile.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic=assignment-to-undeclared-t\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: analytical JVP/VJP, central-difference sweep, adjoint identity\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: true\n'
    printf 'upstream_sha256:\n'
    sha256sum "$source_dir/program.f" "$source_dir/program_p.f" "$source_dir/program_p.msg"
} >"$result"
cat "$result"
