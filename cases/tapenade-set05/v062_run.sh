#!/usr/bin/env bash
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
result="$case_dir/v062_result.txt"
required_fortad_commit=2b404b2957dbc5a8c205fdcf5429970bc75d0fd3
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
upstream_dir="$tapenade_repo/nonRegressions/set05/v062"
source="$upstream_dir/program.f90"

strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto)
command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x "$fortad"
test -x "$tapenade"
test -f "$source"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set05-v062.XXXXXX)
mkdir -p "$out"/mod/{exact,tapenade-parser,tapenade-forward,tapenade-reverse,fortad-forward,fortad-reverse,harness}
mkdir -p "$out"/tapenade/{parser,forward,reverse} "$out"/fortad/{forward,reverse}

compile_strict() {
    "$fc" "${strict[@]}" -J"$3" -I"$3" -c "$1" -o "$2"
}

compile_with_dependency() {
    "$fc" "${strict[@]}" -J"$3" -I"$3" -I"$4" -c "$1" -o "$2"
}

compile_strict "$source" "$out/exact.o" "$out/mod/exact"
(cd "$upstream_dir" && "$tapenade" -p -root func -O "$out/tapenade/parser" -o v062 program.f90)
(cd "$upstream_dir" && "$tapenade" -d -root func -O "$out/tapenade/forward" -o v062 program.f90)
(cd "$upstream_dir" && "$tapenade" -b -root func -O "$out/tapenade/reverse" -o v062 program.f90)

tapenade_parser=$(find "$out/tapenade/parser" -maxdepth 1 -name '*.f90' -print -quit)
tapenade_forward=$(find "$out/tapenade/forward" -maxdepth 1 -name '*.f90' -print -quit)
tapenade_reverse=$(find "$out/tapenade/reverse" -maxdepth 1 -name '*.f90' -print -quit)
test -s "$tapenade_parser"; test -s "$tapenade_forward"; test -s "$tapenade_reverse"
compile_with_dependency "$tapenade_parser" "$out/tapenade-parser.o" "$out/mod/tapenade-parser" "$out/mod/exact"
compile_with_dependency "$tapenade_forward" "$out/tapenade-forward.o" "$out/mod/tapenade-forward" "$out/mod/exact"
compile_with_dependency "$tapenade_reverse" "$out/tapenade-reverse.o" "$out/mod/tapenade-reverse" "$out/mod/exact"

fortad_exec() { (cd "$fortad_repo" && fo exec --no-build fortad "$@"); }
fortad_exec --mode forward --indep t,u --proc func --name v062_jvp \
    --module tapenade_set05_v062_forward --output "$out/fortad/forward/v062_forward.f90" \
    "$case_dir/v062.f90"
fortad_exec --mode reverse --indep t,u --dep value --proc func --name v062_vjp \
    --module tapenade_set05_v062_reverse --output "$out/fortad/reverse/v062_reverse.f90" \
    "$case_dir/v062.f90"
compile_strict "$out/fortad/forward/v062_forward.f90" "$out/fortad-forward.o" "$out/mod/fortad-forward"
compile_strict "$out/fortad/reverse/v062_reverse.f90" "$out/fortad-reverse.o" "$out/mod/fortad-reverse"
compile_strict "$case_dir/v062.f90" "$out/port.o" "$out/mod/exact"
compile_strict "$case_dir/hand_derivative_v062.f90" "$out/hand.o" "$out/mod/exact"
"$fc" "${strict[@]}" -J"$out/mod/harness" -I"$out/mod/exact" \
    -I"$out/mod/fortad-forward" -I"$out/mod/fortad-reverse" -c \
    "$case_dir/v062_harness.f90" -o "$out/harness.o"
"$fc" "${strict[@]}" -J"$out/mod/harness" -I"$out/mod/exact" \
    -I"$out/mod/fortad-forward" -I"$out/mod/fortad-reverse" -o "$out/harness" \
    "$out/port.o" "$out/hand.o" "$out/fortad-forward.o" "$out/fortad-reverse.o" "$out/harness.o"
harness_output=$($out/harness)
grep -Fqx 'harness_status: pass' <<<"$harness_output"
oracle_output=$(python3 "$case_dir/v062_oracle.py" "$source")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions set05 v062 M::func\n'
    printf 'classification: runnable-ported\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_free_flags: %s\n' "${strict[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'entry_point: M::func(t,u)\n'
    printf 'tapenade_modes: parser tangent reverse\n'
    printf 'fortad_modes: forward reverse\n'
    printf 'upstream_exact_strict_compile: pass\n'
    printf 'tapenade_generation: parser=0 tangent=0 reverse=0\n'
    printf 'tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0\n'
    printf 'fortad_transformation: forward=0 reverse=0\n'
    printf 'fortad_generated_strict_compile: forward=0 reverse=0\n'
    printf 'fortad_harness: %s\n' "$harness_output"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, adjoint identity\n'
    printf '%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$upstream_dir" && sha256sum program.f90 program_p.f90 program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$tapenade_parser" "$tapenade_forward" "$tapenade_reverse"
    printf 'fortad_generated_sha256:\n'
    sha256sum "$out/fortad/forward/v062_forward.f90" "$out/fortad/reverse/v062_reverse.f90"
    printf 'case_artifact_sha256:\n'
    sha256sum "$case_dir/v062.f90" "$case_dir/hand_derivative_v062.f90" "$case_dir/v062_manifest.toml" "$case_dir/v062_harness.f90" "$case_dir/v062_oracle.py" "$case_dir/v062_run.sh"
} >"$result"
cat "$result"
