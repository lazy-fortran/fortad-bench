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
result="$case_dir/v065_result.txt"
required_fortad_commit=43087e737c39f220a8134f5fb3579fc412ef07b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
upstream_dir="$tapenade_repo/nonRegressions/set05/v065"

strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto)
command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x "$fortad"
test -x "$tapenade"
test -d "$upstream_dir"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set05-v065.XXXXXX)
mkdir -p "$out"/mod/{exact,tapenade-parser,tapenade-forward,tapenade-reverse,fortad-forward,fortad-reverse,harness}
mkdir -p "$out"/tapenade/{parser,forward,reverse} "$out"/fortad/{forward,reverse}

compile_strict() {
    "$fc" "${strict[@]}" -J"$3" -I"$3" -c "$1" -o "$2"
}

compile_with_dependency() {
    "$fc" "${strict[@]}" -J"$3" -I"$3" -I"$4" -c "$1" -o "$2"
}

exact_sources=(program.f90 program_d.f90 program_p.f90)
for reference in "${exact_sources[@]}"; do
    test -f "$upstream_dir/$reference"
done
for source in "${exact_sources[@]}"; do
    compile_strict "$upstream_dir/$source" "$out/exact-${source%.f90}.o" "$out/mod/exact"
done

(cd "$upstream_dir" && "$tapenade" -p -root mppsum_real2 -O "$out/tapenade/parser" -o v065 program.f90)
(cd "$upstream_dir" && "$tapenade" -d -root mppsum_real2 -O "$out/tapenade/forward" -o v065 program.f90)
(cd "$upstream_dir" && "$tapenade" -b -root mppsum_real2 -O "$out/tapenade/reverse" -o v065 program.f90)

tapenade_parser=$(find "$out/tapenade/parser" -maxdepth 1 -name '*.f90' -print -quit)
tapenade_forward=$(find "$out/tapenade/forward" -maxdepth 1 -name '*.f90' -print -quit)
tapenade_reverse=$(find "$out/tapenade/reverse" -maxdepth 1 -name '*.f90' -print -quit)
test -s "$tapenade_parser"
test -s "$tapenade_forward"
test -s "$tapenade_reverse"
compile_with_dependency "$tapenade_parser" "$out/tapenade-parser.o" "$out/mod/tapenade-parser" "$out/mod/exact"
compile_with_dependency "$tapenade_forward" "$out/tapenade-forward.o" "$out/mod/tapenade-forward" "$out/mod/exact"
compile_with_dependency "$tapenade_reverse" "$out/tapenade-reverse.o" "$out/mod/tapenade-reverse" "$out/mod/exact"

"$fortad" --mode forward --indep ptab --dep value --proc mppsum_real2_value --name v065_jvp \
    --module tapenade_set05_v065_forward --output "$out/fortad/forward/v065_forward.f90" \
    "$case_dir/v065.f90"
"$fortad" --mode reverse --indep ptab --dep value --proc mppsum_real2_value --name v065_vjp \
    --module tapenade_set05_v065_reverse --output "$out/fortad/reverse/v065_reverse.f90" \
    "$case_dir/v065.f90"
compile_strict "$out/fortad/forward/v065_forward.f90" "$out/fortad-forward.o" "$out/mod/fortad-forward"
compile_strict "$out/fortad/reverse/v065_reverse.f90" "$out/fortad-reverse.o" "$out/mod/fortad-reverse"
compile_strict "$case_dir/v065.f90" "$out/port.o" "$out/mod/exact"
compile_strict "$case_dir/hand_derivative_v065.f90" "$out/hand.o" "$out/mod/exact"
"$fc" "${strict[@]}" -J"$out/mod/harness" -I"$out/mod/exact" \
    -I"$out/mod/fortad-forward" -I"$out/mod/fortad-reverse" -c \
    "$case_dir/v065_harness.f90" -o "$out/harness.o"
"$fc" "${strict[@]}" -J"$out/mod/harness" -I"$out/mod/exact" \
    -I"$out/mod/fortad-forward" -I"$out/mod/fortad-reverse" -o "$out/harness" \
    "$out/port.o" "$out/hand.o" "$out/fortad-forward.o" "$out/fortad-reverse.o" "$out/harness.o"
harness_output=$($out/harness)
grep -Fqx 'harness_status: pass' <<<"$harness_output"
oracle_output=$(python3 "$case_dir/v065_oracle.py" "$upstream_dir/program.f90")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions set05 v065 LIB::mppsum_real2(ptab,cst,str)\n'
    printf 'classification: runnable-ported\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_free_flags: %s\n' "${strict[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'entry_point: LIB::mppsum_real2(ptab,cst,str)\n'
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
    (cd "$upstream_dir" && sha256sum program.f90 program_d.f90 program_p.f90)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$tapenade_parser" "$tapenade_forward" "$tapenade_reverse"
    printf 'fortad_generated_sha256:\n'
    sha256sum "$out/fortad/forward/v065_forward.f90" "$out/fortad/reverse/v065_reverse.f90"
    printf 'case_artifact_sha256:\n'
    sha256sum "$case_dir/v065.f90" "$case_dir/hand_derivative_v065.f90" "$case_dir/v065_manifest.toml" "$case_dir/v065_harness.f90" "$case_dir/v065_oracle.py" "$case_dir/v065_run.sh"
} >"$result"
cat "$result"
