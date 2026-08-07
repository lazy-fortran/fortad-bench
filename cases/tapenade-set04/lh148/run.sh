#!/usr/bin/env bash
# Validate the pinned Tapenade set04/lh148 module1::toto entry point.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../../.." && pwd)

default_fortad_repo="$bench_root/../fortad"
default_tapenade_repo="$bench_root/upstream/tapenade"
if test ! -d "$default_fortad_repo" || test ! -d "$default_tapenade_repo"; then
    main_root=$(git -C "$bench_root" worktree list --porcelain | awk 'NR == 1 {print $2}')
    if test -n "$main_root"; then
        test -d "$default_fortad_repo" || default_fortad_repo="$(dirname "$main_root")/fortad"
        test -d "$default_tapenade_repo" || default_tapenade_repo="$main_root/upstream/tapenade"
    fi
fi

fortad_repo=${FORTAD_REPO:-"$default_fortad_repo"}
tapenade_repo=${TAPENADE_REPO:-"$default_tapenade_repo"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
result="$case_dir/result.txt"
required_fortad_commit=7f56c371e22b5c8e6cc953b4f19b94df90f6ab06
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
upstream_dir="$tapenade_repo/nonRegressions/set04/lh148"
source="$upstream_dir/program.f90"

strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
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
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

test "$(sha256sum "$upstream_dir/Options" | awk '{print $1}')" = \
    7b4f5eb287e8fa204540de18918e2713a9a369407cd41ca24afeeeae7fdb5d89
test "$(sha256sum "$source" | awk '{print $1}')" = \
    7bc40e8c177160274e187a1c22f8a7e5b040b87c9840ebb728fe3c6bb4ef5872
test "$(sha256sum "$upstream_dir/program_bv.f90" | awk '{print $1}')" = \
    bfd7151214439c93835f0d0eefce6928b21114d235a7ced280386c9b381994e2
test "$(sha256sum "$upstream_dir/program_bv.msg" | awk '{print $1}')" = \
    dc18ec7b60772241312efc64fb4644faaf76a833dbeeba1ffdd60af74d4ae025

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set04-lh148.XXXXXX)
mkdir -p "$out"/mod/{exact,tapenade-parser,tapenade-forward,tapenade-reverse,fortad-forward,fortad-reverse,harness} \
    "$out"/tapenade/{parser,forward,reverse} "$out"/fortad/{forward,reverse}

compile_strict() {
    local input=$1 output=$2 module_dir=$3
    "$fc" "${strict[@]}" -J"$module_dir" -I"$module_dir" -c "$input" -o "$output"
}

compile_strict "$source" "$out/exact.o" "$out/mod/exact"

(cd "$upstream_dir" && "$tapenade" -p -root toto -O "$out/tapenade/parser" \
    -o lh148 program.f90)
(cd "$upstream_dir" && "$tapenade" -d -root toto -O "$out/tapenade/forward" \
    -o lh148 program.f90)
(cd "$upstream_dir" && "$tapenade" -b -root toto -O "$out/tapenade/reverse" \
    -o lh148 program.f90)

tapenade_parser=$(find "$out/tapenade/parser" -maxdepth 1 -type f -name '*.f90' -print -quit)
tapenade_forward=$(find "$out/tapenade/forward" -maxdepth 1 -type f -name '*.f90' -print -quit)
tapenade_reverse=$(find "$out/tapenade/reverse" -maxdepth 1 -type f -name '*.f90' -print -quit)
test -s "$tapenade_parser"
test -s "$tapenade_forward"
test -s "$tapenade_reverse"
compile_strict "$tapenade_parser" "$out/tapenade-parser.o" "$out/mod/tapenade-parser"
compile_strict "$tapenade_forward" "$out/tapenade-forward.o" "$out/mod/tapenade-forward"
compile_strict "$tapenade_reverse" "$out/tapenade-reverse.o" "$out/mod/tapenade-reverse"

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

fortad_exec --mode forward --indep a,b,c --proc toto --name lh148_jvp \
    --module lh148_forward --output "$out/fortad/forward/lh148_forward.f90" "$source"
fortad_exec --mode reverse --indep a,b,c --dep d --proc toto --name lh148_vjp \
    --module lh148_reverse --output "$out/fortad/reverse/lh148_reverse.f90" "$source"
test -s "$out/fortad/forward/lh148_forward.f90"
test -s "$out/fortad/reverse/lh148_reverse.f90"
compile_strict "$out/fortad/forward/lh148_forward.f90" "$out/fortad-forward.o" \
    "$out/mod/fortad-forward"
compile_strict "$out/fortad/reverse/lh148_reverse.f90" "$out/fortad-reverse.o" \
    "$out/mod/fortad-reverse"

"$fc" "${strict[@]}" -J"$out/mod/harness" \
    -I"$out/mod/exact" -I"$out/mod/fortad-forward" \
    -I"$out/mod/fortad-reverse" -c "$case_dir/harness.f90" \
    -o "$out/harness.o"
"$fc" "${strict[@]}" -J"$out/mod/harness" \
    -I"$out/mod/exact" -I"$out/mod/fortad-forward" \
    -I"$out/mod/fortad-reverse" -o "$out/harness" \
    "$out/exact.o" "$out/fortad-forward.o" "$out/fortad-reverse.o" \
    "$out/harness.o"
harness_output=$("$out/harness")
grep -Fqx 'harness_status: pass' <<<"$harness_output"

oracle_output=$(python3 "$case_dir/oracle.py" "$source")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

{
    printf 'case: Tapenade nonRegressions set04 lh148 module1::toto\n'
    printf 'classification: runnable-ported\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_free_flags: %s\n' "${strict[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'entry_point: toto(a,b,c,d)\n'
    printf 'tapenade_modes: parser forward reverse\n'
    printf 'fortad_modes: forward reverse\n'
    printf 'upstream_exact_strict_compile: pass\n'
    printf 'tapenade_generation: parser=0 tangent=0 reverse=0\n'
    printf 'tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0\n'
    printf 'fortad_transformation: forward=0 reverse=0\n'
    printf 'fortad_generated_strict_compile: forward=0 reverse=0\n'
    printf 'fortad_harness: %s\n' "$harness_output"
    printf 'independent_oracle: closed-form product JVP/VJP, central-difference sweep, adjoint identity\n'
    printf '%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$upstream_dir" && sha256sum Options program.f90 program_bv.f90 program_bv.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$tapenade_parser" "$tapenade_forward" "$tapenade_reverse"
    printf 'fortad_generated_sha256:\n'
    sha256sum "$out/fortad/forward/lh148_forward.f90" "$out/fortad/reverse/lh148_reverse.f90"
    printf 'case_artifact_sha256:\n'
    sha256sum "$case_dir/manifest.toml" "$case_dir/notes.md" "$case_dir/oracle.py" \
        "$case_dir/harness.f90" "$case_dir/run.sh" "$case_dir/test_contract.py"
} >"$result"
cat "$result"
