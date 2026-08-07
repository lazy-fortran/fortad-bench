#!/usr/bin/env bash
# Validate the pinned Tapenade set05/v066 invalid-upstream closure.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../.." && pwd)
fortad_repo=${FORTAD_REPO:-"$bench_root/../fortad"}
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
result="$case_dir/v066_result.txt"
required_fortad_commit=253f59d516edd8b62fc44c8774cdd852cfa1f7cf
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
source_dir="$tapenade_repo/nonRegressions/set05/v066"

strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto)
command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x "$fortad"
test -x "$tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set05-v066.XXXXXX)
mkdir -p "$out"/exact-mod "$out"/fresh/{parser,forward,reverse}
mkdir -p "$out"/fresh/{parser,forward,reverse}-mod "$out"/fortad

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
    run_capture "$label" "$fc" "${strict[@]}" -I"$source_dir" -J"$moddir" -c "$source" -o "$out/$label.o"
}

for source in program.f90 program_d.f90 program_d.msg; do
    test -s "$source_dir/$source"
done

compile_capture exact-program "$source_dir/program.f90" "$out/exact-mod"
compile_capture exact-stored "$source_dir/program_d.f90" "$out/exact-mod"
test "$(cat "$out/exact-program.status")" -ne 0
test "$(cat "$out/exact-stored.status")" -ne 0
grep -Fqi "Ambiguous interfaces in generic interface 'func'" "$out/exact-program.stderr"
grep -Fqi "Ambiguous interfaces in generic interface 'func'" "$out/exact-stored.stderr"

for mode_spec in "parser -p p" "forward -d d" "reverse -b b"; do
    set -- $mode_spec
    mode=$1
    option=$2
    suffix=$3
    run_capture "tapenade-$mode-generation" bash -c \
        "cd '$source_dir' && '$tapenade' '$option' -root s -O '$out/fresh/$mode' -o v066 program.f90"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    generated="$out/fresh/$mode/v066_${suffix}.f90"
    test -s "$generated"
    test -s "$out/fresh/$mode/v066_${suffix}.msg"
    compile_capture "fresh-$mode" "$generated" "$out/fresh/$mode-mod"
    test "$(cat "$out/fresh-$mode.status")" -ne 0
    grep -Fqi "Ambiguous interfaces in generic interface 'func'" "$out/fresh-$mode.stderr"
done

run_capture fortad-parser bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad check --proc s --output '$out/fortad/parser.f90' '$source_dir/program.f90'"
test "$(cat "$out/fortad-parser.status")" -eq 0
test -s "$out/fortad/parser.f90"

run_capture fortad-forward bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad --mode forward --indep mb1 --proc s --name v066_jvp --module tapenade_set05_v066_forward --output '$out/fortad/forward.f90' '$source_dir/program.f90'"
run_capture fortad-reverse bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad --mode reverse --indep mb1 --dep mb1 --proc s --name v066_vjp --module tapenade_set05_v066_reverse --output '$out/fortad/reverse.f90' '$source_dir/program.f90'"
test "$(cat "$out/fortad-forward.status")" -ne 0
test "$(cat "$out/fortad-reverse.status")" -ne 0
grep -Fq "fortad: no derivative rule for the call to 'func'" "$out/fortad-forward.stderr"
grep -Fq "fortad: no reverse rule for the call to 'func'" "$out/fortad-reverse.stderr"
test ! -e "$out/fortad/forward.f90"
test ! -e "$out/fortad/reverse.f90"

oracle_output=$(python3 "$case_dir/v066_oracle.py" "$source_dir" "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions set05 v066 RUN::s(mb1,mb2,mb3,mb4)\n'
    printf 'classification: unsupported-invalid-upstream-fortran\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_free_flags: %s\n' "${strict[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'entry_point: RUN::s(mb1,mb2,mb3,mb4)\n'
    printf 'tapenade_modes: parser tangent reverse\n'
    printf 'fortad_modes: parser forward reverse\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_d.f90=%s\n' \
        "$(cat "$out/exact-program.status")" "$(cat "$out/exact-stored.status")"
    printf 'upstream_diagnostic: ambiguous generic FUNC interface; unmatched 10x50 and 10x70 calls\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser.status")" "$(cat "$out/fresh-forward.status")" \
        "$(cat "$out/fresh-reverse.status")"
    printf 'fortad_parser: pass-exact-procedure-extraction status=%s\n' "$(cat "$out/fortad-parser.status")"
    printf 'fortad_forward: expected-refusal status=%s diagnostic="no derivative rule for the call to func"\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_reverse: expected-refusal status=%s diagnostic="no reverse rule for the call to func"\n' "$(cat "$out/fortad-reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: source invariants plus strict compiler refusal; no numerical semantics-preserving port exists\n'
    printf '%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f90 program_d.f90 program_d.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/fresh/parser/v066_p.f90" "$out/fresh/parser/v066_p.msg" \
        "$out/fresh/forward/v066_d.f90" "$out/fresh/forward/v066_d.msg" \
        "$out/fresh/reverse/v066_b.f90" "$out/fresh/reverse/v066_b.msg"
    printf 'case_artifact_sha256:\n'
    sha256sum "$case_dir/v066_manifest.toml" "$case_dir/v066_notes.md" \
        "$case_dir/v066_oracle.py" "$case_dir/v066_run.sh"
} >"$result"
cat "$result"
