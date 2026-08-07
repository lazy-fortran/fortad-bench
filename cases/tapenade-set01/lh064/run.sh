#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if [[ ! -d "$fortad_repo/.git" && -d /home/ert/code/lazy-fortran/fortad/.git ]]; then
    fortad_repo=/home/ert/code/lazy-fortran/fortad
fi
if [[ ! -d "$tapenade_repo/.git" && -d /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git ]]; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi

result="$case_dir/result.txt"
fortad_pin=0e156041c1f92736c1e35f8164b37992c4c8d780
tapenade_pin=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh064"
out=$(mktemp -d /var/tmp/fortad-set01-lh064.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/fortad" "$out/mod"

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
command -v fo >/dev/null
test -x "$tapenade_repo/bin/tapenade"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$tapenade_pin"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
fortad_original_commit=$(git -C "$fortad_repo" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_repo" status --porcelain --untracked-files=no)
clean_fortad_repo=
if test "$fortad_original_commit" != "$fortad_pin" || test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_repo")/fortad-lh064-clean.XXXXXX")
    rmdir "$clean_fortad_repo"
    git clone --shared --quiet "$fortad_repo" "$clean_fortad_repo"
    git -C "$clean_fortad_repo" checkout --detach --quiet "$fortad_pin"
    fortad_repo="$clean_fortad_repo"
fi
cleanup() {
    if test -n "$clean_fortad_repo"; then
        rm -rf "$clean_fortad_repo"
    fi
    rm -rf "$out"
}
trap cleanup EXIT
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$fortad_pin"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
for f in program.f program_p.f program_d.f program_b.f \
         program_p.msg program_d.msg program_b.msg; do
    test -f "$source_dir/$f"
done

compile_fixed() {
    local source=$1 label=$2
    set +e
    "$fc" "${fixed[@]}" -c "$source" -o "$out/$label.o" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status"
}

compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status"
}

upstream_program=$(compile_fixed "$source_dir/program.f" upstream_program)
upstream_parser=$(compile_fixed "$source_dir/program_p.f" upstream_parser)
upstream_tangent=$(compile_fixed "$source_dir/program_d.f" upstream_tangent)
upstream_reverse=$(compile_fixed "$source_dir/program_b.f" upstream_reverse)
test "$upstream_program" -ne 0
test "$upstream_parser" -eq 0
test "$upstream_tangent" -eq 0
test "$upstream_reverse" -ne 0
grep -Fq 'Legacy Extension: Missing comma in FORMAT string' "$out/upstream_program.log"
grep -Fq 'GNU Extension: Nonstandard type declaration INTEGER*4' "$out/upstream_reverse.log"

tapenade="$tapenade_repo/bin/tapenade"
(cd "$out/tapenade/parser" && "$tapenade" -p -root cg02v1 -o lh064 "$source_dir/program.f") \
    >"$out/tapenade-parser.log" 2>&1
(cd "$out/tapenade/forward" && "$tapenade" -d -root cg02v1 -o lh064 "$source_dir/program.f") \
    >"$out/tapenade-forward.log" 2>&1
(cd "$out/tapenade/reverse" && "$tapenade" -b -root cg02v1 -o lh064 "$source_dir/program.f") \
    >"$out/tapenade-reverse.log" 2>&1
for generated in "$out/tapenade/parser/lh064_p.f" \
                 "$out/tapenade/forward/lh064_d.f" \
                 "$out/tapenade/reverse/lh064_b.f"; do
    test -s "$generated"
done
fresh_parser=$(compile_fixed "$out/tapenade/parser/lh064_p.f" fresh_parser)
fresh_tangent=$(compile_fixed "$out/tapenade/forward/lh064_d.f" fresh_tangent)
fresh_reverse=$(compile_fixed "$out/tapenade/reverse/lh064_b.f" fresh_reverse)
test "$fresh_parser" -eq 0
test "$fresh_tangent" -eq 0
test "$fresh_reverse" -ne 0
grep -Fq 'GNU Extension: Nonstandard type declaration INTEGER*4' "$out/fresh_reverse.log"

fortad="$fortad_repo/build/fo/bin/fortad"
if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
test -x "$fortad"
set +e
"$fortad" --mode forward --indep T --dep T --proc cg02v1 --name lh064_exact_forward \
    --module lh064_exact_forward_mod --output "$out/exact_forward.f90" "$source_dir/program.f" \
    >"$out/exact-forward.log" 2>&1
exact_forward=$?
"$fortad" --mode reverse --indep T --dep T --proc cg02v1 --name lh064_exact_reverse \
    --module lh064_exact_reverse_mod --output "$out/exact_reverse.f90" "$source_dir/program.f" \
    >"$out/exact-reverse.log" 2>&1
exact_reverse=$?
set -e
test "$exact_forward" -ne 0
test "$exact_reverse" -ne 0
grep -Fq 'Unterminated character constant' "$out/exact-forward.log"
grep -Fq 'Unterminated character constant' "$out/exact-reverse.log"
test ! -e "$out/exact_forward.f90"
test ! -e "$out/exact_reverse.f90"

set +e
"$fortad" --mode forward --indep t --dep t --proc set01_lh064 --name lh064_forward \
    --module lh064_forward_mod --output "$out/fortad/lh064_forward.f90" "$case_dir/port.f90" \
    >"$out/fortad-forward.log" 2>&1
bounded_forward=$?
"$fortad" --mode reverse --indep t --dep t --proc set01_lh064 --name lh064_reverse \
    --module lh064_reverse_mod --output "$out/fortad/lh064_reverse.f90" "$case_dir/port.f90" \
    >"$out/fortad-reverse.log" 2>&1
bounded_reverse=$?
set -e
test "$bounded_forward" -eq 0
test "$bounded_reverse" -ne 0
test -s "$out/fortad/lh064_forward.f90"
test ! -e "$out/fortad/lh064_reverse.f90"
grep -Fq 'needs per-iteration storage' "$out/fortad-reverse.log"

port_status=$(compile_free "$case_dir/port.f90" bounded_port)
hand_status=$(compile_free "$case_dir/hand.f90" hand)
forward_status=$(compile_free "$out/fortad/lh064_forward.f90" bounded_forward)
test "$port_status" -eq 0
test "$hand_status" -eq 0
test "$forward_status" -eq 0
compile_free "$case_dir/harness.f90" harness >/dev/null
"$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" \
    "$out/bounded_port.o" "$out/hand.o" "$out/bounded_forward.o" "$out/harness.o" \
    >"$out/link.log" 2>&1
"$out/harness" >"$out/harness.log"
grep -Fq 'harness_status: pass' "$out/harness.log"

oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh064\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${fixed[*]}"
    printf 'strict_free_flags: %s\n' "${free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$fortad_pin"
    printf 'tapenade_commit: %s\n' "$tapenade_pin"
    printf 'upstream_exact_strict_compile: program=%s parser=%s tangent=%s reverse=%s\n' \
        "$upstream_program" "$upstream_parser" "$upstream_tangent" "$upstream_reverse"
    printf 'upstream_diagnostic_contract: program=legacy-FORMAT-literal reverse=INTEGER*4\n'
    printf 'tapenade_options: parser=-p/-root cg02v1 tangent=-d/-root cg02v1 reverse=-b/-root cg02v1\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser" "$fresh_tangent" "$fresh_reverse"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic=unterminated-character-constant\n' "$exact_forward"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic=unterminated-character-constant\n' "$exact_reverse"
    printf 'fortad_bounded_forward: pass-transform-compile-runtime status=%s\n' "$bounded_forward"
    printf 'fortad_bounded_reverse: expected-refusal status=%s diagnostic=per-iteration-storage\n' "$bounded_reverse"
    printf 'fortad_bounded_forward_strict_compile: %s\n' "$forward_status"
    printf 'bounded_port_strict_compile: %s\n' "$port_status"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, adjoint identity\n'
    printf '%s\n' "$oracle_output"
    cat "$out/harness.log"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f \
        program_p.msg program_d.msg program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/tapenade/parser/lh064_p.f" "$out/tapenade/parser/lh064_p.msg" \
        "$out/tapenade/forward/lh064_d.f" "$out/tapenade/forward/lh064_d.msg" \
        "$out/tapenade/reverse/lh064_b.f" "$out/tapenade/reverse/lh064_b.msg"
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh064/manifest.toml \
        cases/tapenade-set01/lh064/notes.md cases/tapenade-set01/lh064/port.f90 \
        cases/tapenade-set01/lh064/hand.f90 cases/tapenade-set01/lh064/harness.f90 \
        cases/tapenade-set01/lh064/oracle.py cases/tapenade-set01/lh064/run.sh \
        cases/tapenade-set01/lh064/test_contract.py)
} >"$result"
cat "$result"
