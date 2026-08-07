#!/usr/bin/env bash
# Validate the pinned Tapenade set05/v068 invalid-upstream closure.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../.." && pwd)
fortad_repo=${FORTAD_REPO:-"$bench_root/../../fortad"}
if test ! -d "$fortad_repo"; then
    fortad_repo="$bench_root/../fortad"
fi
tapenade_repo=${TAPENADE_REPO:-"$bench_root/upstream/tapenade"}
if test ! -d "$tapenade_repo"; then
    main_root=$(git -C "$bench_root" worktree list --porcelain | awk 'NR == 1 {print $2}')
    tapenade_repo="$main_root/upstream/tapenade"
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
result="$case_dir/v068_result.txt"
required_fortad_commit=a41afdec1502e0399a145f7e68728e0cc6c1d915
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
source_dir="$tapenade_repo/nonRegressions/set05/v068"

strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto)
legacy=(-std=legacy -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto)
command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x "$fortad"
test -x "$tapenade"
test -f "$tapenade_repo/build/libs/tapenade-3.16.jar"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set05-v068.XXXXXX)
mkdir -p "$out"/exact/{strict,legacy} "$out"/fresh/{parser,tangent,reverse}
mkdir -p "$out"/fresh-mod/{parser-strict,parser-legacy,tangent-strict,tangent-legacy,reverse-strict,reverse-legacy}
mkdir -p "$out"/fortad

run_capture() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_capture() {
    local label=$1
    local source=$2
    local moddir=$3
    local flavor=$4
    local flags=()
    if test "$flavor" = strict; then
        flags=("${strict[@]}")
    else
        flags=("${legacy[@]}")
    fi
    mkdir -p "$moddir"
    run_capture "$label" "$fc" "${flags[@]}" -I"$source_dir" -J"$moddir" -c "$source" -o "$out/$label.o"
}

for source in program.f90 program_p.f90 program_p.msg; do
    test -s "$source_dir/$source"
done

for source in program.f90 program_p.f90; do
    stem=${source%.f90}
    compile_capture "exact-strict-$stem" "$source_dir/$source" "$out/exact/strict/$stem" strict
    compile_capture "exact-legacy-$stem" "$source_dir/$source" "$out/exact/legacy/$stem" legacy
    for flavor in strict legacy; do
        test "$(cat "$out/exact-$flavor-$stem.status")" -ne 0
        grep -Fqi "no specific subroutine for the generic" "$out/exact-$flavor-$stem.stderr"
    done
done

for mode_spec in "parser -p p func" "tangent -d d func_d" "reverse -b b func_b"; do
    set -- $mode_spec
    mode=$1
    option=$2
    suffix=$3
    generic=$4
    run_capture "tapenade-$mode-generation" bash -c \
        "cd '$source_dir' && '$tapenade' '$option' -root s -O '$out/fresh/$mode' -o v068 program.f90"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    generated="$out/fresh/$mode/v068_${suffix}.f90"
    test -s "$generated"
    test -s "$out/fresh/$mode/v068_${suffix}.msg"
    for flavor in strict legacy; do
        compile_capture "fresh-$flavor-$mode" "$generated" "$out/fresh-mod/$mode-$flavor" "$flavor"
        test "$(cat "$out/fresh-$flavor-$mode.status")" -ne 0
        grep -Fqi "no specific subroutine for the generic" "$out/fresh-$flavor-$mode.stderr"
    done
done

run_capture fortad-parser bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad check --proc s --output '$out/fortad/parser.f90' '$source_dir/program.f90'"
test "$(cat "$out/fortad-parser.status")" -ne 0
grep -Fq "conversion-required generic call 'func' has no exact candidate" \
    "$out/fortad-parser.stderr"
test ! -e "$out/fortad/parser.f90"

run_capture fortad-forward bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad --mode forward --indep mb1 --proc s --name v068_jvp --module tapenade_set05_v068_forward --output '$out/fortad/forward.f90' '$source_dir/program.f90'"
run_capture fortad-reverse bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad --mode reverse --indep mb1 --dep mb1 --proc s --name v068_vjp --module tapenade_set05_v068_reverse --output '$out/fortad/reverse.f90' '$source_dir/program.f90'"
test "$(cat "$out/fortad-forward.status")" -ne 0
test "$(cat "$out/fortad-reverse.status")" -ne 0
grep -Fq "conversion-required generic call 'func' has no exact candidate" \
    "$out/fortad-forward.stderr"
grep -Fq "conversion-required generic call 'func' has no exact candidate" \
    "$out/fortad-reverse.stderr"
test ! -e "$out/fortad/forward.f90"
test ! -e "$out/fortad/reverse.f90"

oracle_output=$(python3 "$case_dir/v068_oracle.py" "$source_dir" "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions set05 v068 RUN::s(mb1,mb2,mb3)\n'
    printf 'classification: unsupported-invalid-upstream-fortran\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_free_flags: %s\n' "${strict[*]}"
    printf 'legacy_free_flags: %s\n' "${legacy[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'entry_point: RUN::s(mb1,mb2,mb3)\n'
    printf 'tapenade_modes: parser tangent reverse\n'
    printf 'fortad_modes: parser forward reverse\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_p.f90=%s\n' \
        "$(cat "$out/exact-strict-program.status")" "$(cat "$out/exact-strict-program_p.status")"
    printf 'upstream_exact_legacy_compile: program.f90=%s program_p.f90=%s\n' \
        "$(cat "$out/exact-legacy-program.status")" "$(cat "$out/exact-legacy-program_p.status")"
    printf 'upstream_diagnostic: no specific subroutine for generic FUNC; REAL*8 mismatch remains in the exact source\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" "$(cat "$out/tapenade-tangent-generation.status")" "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-strict-parser.status")" "$(cat "$out/fresh-strict-tangent.status")" "$(cat "$out/fresh-strict-reverse.status")"
    printf 'tapenade_fresh_legacy_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-legacy-parser.status")" "$(cat "$out/fresh-legacy-tangent.status")" "$(cat "$out/fresh-legacy-reverse.status")"
    printf 'fortad_parser: expected-refusal status=%s diagnostic="conversion-required generic call func has no exact candidate"\n' "$(cat "$out/fortad-parser.status")"
    printf 'fortad_forward: expected-refusal status=%s diagnostic="conversion-required generic call func has no exact candidate"\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_reverse: expected-refusal status=%s diagnostic="conversion-required generic call func has no exact candidate"\n' "$(cat "$out/fortad-reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: generic procedure and kind mismatch plus strict and legacy compiler refusal\n'
    printf '%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f90 program_p.f90 program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/fresh/parser/v068_p.f90" "$out/fresh/parser/v068_p.msg" \
        "$out/fresh/tangent/v068_d.f90" "$out/fresh/tangent/v068_d.msg" \
        "$out/fresh/reverse/v068_b.f90" "$out/fresh/reverse/v068_b.msg"
    printf 'case_artifact_sha256:\n'
    sha256sum "$case_dir/v068_manifest.toml" "$case_dir/v068_notes.md" \
        "$case_dir/v068_oracle.py" "$case_dir/v068_run.sh"
} >"$result"
cat "$result"
