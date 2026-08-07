#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "$0")" && pwd)
bench_root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=${FORTAD_REPO:-"$bench_root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$bench_root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
source_file="$tapenade_repo/nonRegressions/set02/lh163/program.f"
result="$case_dir/result.txt"
out=$(mktemp -d /var/tmp/ert/tapenade-set02-lh163.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod"

test -x "$fortad"
test -x "$tapenade"
test -f "$source_file"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "e59864cab441d4175df75383b3ff58c3dcd26df9"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "a1c9f25f87eaadf700ba47ee3e841a0fb41585a3"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -fsyntax-only)
normal=(-std=f2018 -ffree-line-length-none -O2 -fno-lto)
compile_strict() { "$fc" "${strict[@]}" -I"$(dirname "$source_file")" "$1"; }
compile_normal() { "$fc" "${normal[@]}" -J"$out/mod" -I"$out/mod" -c "$1" -o "$2"; }

compile_strict "$source_file"

mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse"
for mode in -p -d -b; do
    case "$mode" in
        -p) output="$out/tapenade/parser" ;;
        -d) output="$out/tapenade/forward" ;;
        -b) output="$out/tapenade/reverse" ;;
    esac
    "$tapenade" "$mode" -root test -O "$output" -o lh163 "$source_file"
    generated=$(find "$output" -maxdepth 1 -type f \( -name '*.f' -o -name '*.f90' \) -print -quit)
    test -n "$generated"
    compile_strict "$generated"
done

mkdir -p "$out/fortad/parser" "$out/fortad/forward" "$out/fortad/reverse"
for mode in -p -d -b; do
    case "$mode" in
        -p) output="$out/fortad/parser" ;;
        -d) output="$out/fortad/forward" ;;
        -b) output="$out/fortad/reverse" ;;
    esac
    "$fortad" "$mode" -root test -O "$output" -o lh163 "$source_file"
    generated=$(find "$output" -maxdepth 1 -type f -name '*.f90' -print -quit)
    test -n "$generated"
    if test "$mode" = -p; then
        compile_normal "$generated" "$out/parser.o"
    elif test "$mode" = -d; then
        compile_normal "$generated" "$out/forward.o"
    else
        compile_normal "$generated" "$out/reverse.o"
    fi
done

compile_normal "$case_dir/hand.f90" "$out/hand.o"
compile_normal "$case_dir/harness.f90" "$out/harness.o"
"$fc" "${normal[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/forward.o" "$out/reverse.o" "$out/hand.o" "$out/harness.o"
"$out/bench" >"$out/run.txt"
cat "$out/run.txt"
grep -Fqx 'oracle_status: pass' "$out/run.txt"
oracle=$(python3 "$case_dir/oracle.py" "$case_dir/program.f")
grep -Fqx 'oracle_status: pass' <<<"$oracle"

{
    printf 'classification: runnable-ported\n'
    printf 'suite: Tapenade nonRegressions set02 (lh163)\n'
    printf 'upstream_revision: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'fortad_revision: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_modes: parser forward reverse\n'
    printf 'fortad_modes: parser forward reverse\n'
    printf 'upstream_exact_source: strict fixed-form compile pass\n'
    printf 'tapenade_generated_sources: parser forward reverse strict compile pass\n'
    printf 'fortad_generated_sources: forward reverse normal compile pass\n'
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, adjoint identity\n'
    printf 'oracle_behavioral_cases: 3\n'
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    sha256sum "$case_dir/program.f" "$case_dir/hand.f90" "$case_dir/harness.f90" "$case_dir/manifest.toml"
} >"$result"
cat "$result"
