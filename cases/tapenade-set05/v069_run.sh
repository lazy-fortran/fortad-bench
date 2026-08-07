#!/usr/bin/env bash
set -euo pipefail
case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../.." && pwd)
fortad_repo=${FORTAD_REPO:-"$bench_root/../../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$bench_root/upstream/tapenade"}
if test ! -d "$tapenade_repo"; then
  main_root=$(git -C "$bench_root" worktree list --porcelain | awk 'NR == 1 {print $2}')
  tapenade_repo="$main_root/upstream/tapenade"
fi
fortad_repo=$(cd "$fortad_repo" && pwd); tapenade_repo=$(cd "$tapenade_repo" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"; tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}; result="$case_dir/v069_result.txt"
required_fortad_commit=a41afdec1502e0399a145f7e68728e0cc6c1d915
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
source_rel=nonRegressions/set05/v069; source_dir="$tapenade_repo/$source_rel"
strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
legacy=(-std=legacy -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
for tool in "$fc" java python3 fo; do command -v "$tool" >/dev/null; done
test -e "$fortad_repo/.git"; test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade"; test -f "$tapenade_repo/build/libs/tapenade-3.16.jar"
if test ! -x "$fortad"; then (cd "$fortad_repo" && fo build) >/dev/null; fi
test -x "$fortad"
for source in Options program.f90 program_d.f90 program_d.msg; do test -s "$source_dir/$source"; done
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set05-v069.XXXXXX)
mkdir -p "$out/mod"/{exact-strict,exact-legacy,parser-strict,parser-legacy,tangent-strict,tangent-legacy,reverse-strict,reverse-legacy} "$out/fresh"/{parser,tangent,reverse} "$out/fortad"
run_capture() { local label=$1; shift; local status=0; "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?; printf '%s\n' "$status" >"$out/$label.status"; }
compile_capture() { local label=$1 source=$2 moddir=$3 flavor=$4 flags=(); if test "$flavor" = strict; then flags=("${strict[@]}"); else flags=("${legacy[@]}"); fi; run_capture "$label" "$fc" "${flags[@]}" -I"$source_dir" -J"$moddir" -c "$source" -o "$out/$label.o"; }
for source in program.f90 program_d.f90; do
  stem=${source%.f90}
  for flavor in strict legacy; do
    compile_capture "exact-$flavor-$stem" "$source_dir/$source" "$out/mod/exact-$flavor" "$flavor"
    test "$(cat "$out/exact-$flavor-$stem.status")" -ne 0
    grep -Eiq "print statement at.*pure procedure" "$out/exact-$flavor-$stem.stderr"
  done
done
for mode_spec in "parser -p p" "tangent -d d" "reverse -b b"; do
  set -- $mode_spec; mode=$1; option=$2; suffix=$3
  run_capture "tapenade-$mode-generation" bash -c "cd '$source_dir' && '$tapenade' '$option' -root s -O '$out/fresh/$mode' -o v069 program.f90"
  test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
  generated="$out/fresh/$mode/v069_${suffix}.f90"; test -s "$generated"; test -s "$out/fresh/$mode/v069_${suffix}.msg"
  for flavor in strict legacy; do
    compile_capture "fresh-$flavor-$mode" "$generated" "$out/mod/$mode-$flavor" "$flavor"
    test "$(cat "$out/fresh-$flavor-$mode.status")" -ne 0
    grep -Eiq "print statement at.*pure procedure" "$out/fresh-$flavor-$mode.stderr"
  done
done
run_capture fortad-parser "$fortad" check --proc s --output "$out/fortad/parser.f90" "$source_dir/program.f90"
run_capture fortad-forward "$fortad" --mode forward --indep mb1 --proc s --name v069_jvp --module tapenade_set05_v069_forward --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_capture fortad-reverse "$fortad" --mode reverse --indep mb1 --dep mb1 --proc s --name v069_vjp --module tapenade_set05_v069_reverse --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
  test "$(cat "$out/fortad-$mode.status")" -ne 0
  grep -Fq "fortad: unknown-type generic call 'func': no derivative output" "$out/fortad-$mode.stderr"
  test ! -e "$out/fortad/$mode.f90"
done
oracle_output=$(python3 "$case_dir/v069_oracle.py" "$source_dir" "$fc"); grep -Fqx "oracle_status: pass" <<<"$oracle_output"
{
  printf 'case: Tapenade nonRegressions set05 v069 RUN::s(mb1,mb2,mb3)\n'
  printf 'classification: unsupported-invalid-upstream-fortran\n'
  printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'compiler: %s\n' "$($fc --version | head -1)"
  printf 'strict_free_flags: %s\n' "${strict[*]}"; printf 'legacy_free_flags: %s\n' "${legacy[*]}"
  printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"; printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
  printf 'entry_point: RUN::s(mb1,mb2,mb3)\n'; printf 'tapenade_modes: parser tangent reverse\n'; printf 'fortad_modes: parser forward reverse\n'
  printf 'upstream_exact_strict_compile: program.f90=%s program_d.f90=%s\n' "$(cat "$out/exact-strict-program.status")" "$(cat "$out/exact-strict-program_d.status")"
  printf 'upstream_exact_legacy_compile: program.f90=%s program_d.f90=%s\n' "$(cat "$out/exact-legacy-program.status")" "$(cat "$out/exact-legacy-program_d.status")"
  printf 'upstream_diagnostic: ELEMENTAL implies PURE, but FUNC2/FUNC3 PRINT; strict also rejects REAL*8\n'
  printf 'stored_diagnostic: program_d.msg TC30 type mismatch in argument 1 of procedure func, expected REAL(3), is here REAL*8(3)\n'
  printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' "$(cat "$out/tapenade-parser-generation.status")" "$(cat "$out/tapenade-tangent-generation.status")" "$(cat "$out/tapenade-reverse-generation.status")"
  printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' "$(cat "$out/fresh-strict-parser.status")" "$(cat "$out/fresh-strict-tangent.status")" "$(cat "$out/fresh-strict-reverse.status")"
  printf 'tapenade_fresh_legacy_compile: parser=%s tangent=%s reverse=%s\n' "$(cat "$out/fresh-legacy-parser.status")" "$(cat "$out/fresh-legacy-tangent.status")" "$(cat "$out/fresh-legacy-reverse.status")"
  for mode in parser forward reverse; do printf 'fortad_%s: expected-refusal status=%s diagnostic="unknown-type generic call func: no derivative output"\n' "$mode" "$(cat "$out/fortad-$mode.status")"; done
  printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
  printf 'independent_oracle: elemental-pure PRINT plus REAL*8, stored generic-call message, and strict/legacy compiler refusal\n%s\n' "$oracle_output"
  printf 'exact_source_sha256:\n'; (cd "$tapenade_repo" && sha256sum "$source_rel/program.f90")
  printf 'stored_source_sha256:\n'; (cd "$tapenade_repo" && sha256sum "$source_rel/program_d.f90" "$source_rel/program_d.msg")
  printf 'upstream_support_sha256:\n'; (cd "$tapenade_repo" && sha256sum "$source_rel/Options")
  printf 'fresh_tapenade_sha256:\n'; sha256sum "$out/fresh/parser/v069_p.f90" "$out/fresh/parser/v069_p.msg" "$out/fresh/tangent/v069_d.f90" "$out/fresh/tangent/v069_d.msg" "$out/fresh/reverse/v069_b.f90" "$out/fresh/reverse/v069_b.msg"
  printf 'case_artifact_sha256:\n'; (cd "$bench_root" && sha256sum cases/tapenade-set05/v069_manifest.toml cases/tapenade-set05/v069_notes.md cases/tapenade-set05/v069_oracle.py cases/tapenade-set05/v069_run.sh cases/tapenade-set05/v069_test_contract.py)
  printf 'closure: invalid-upstream; no standard-conforming port, derivative oracle, or support claim\n'
} >"$result"
cat "$result"
