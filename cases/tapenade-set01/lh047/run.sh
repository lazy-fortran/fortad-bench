#!/usr/bin/env bash
# Validate pinned Tapenade set01/lh047 with exact, fresh, and bounded evidence.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh047"

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v python3 >/dev/null
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_d.f program_b.f program_d.msg program_b.msg; do test -s "$source_dir/$source"; done

out=$(mktemp -d /var/tmp/tapenade-set01-lh047.XXXXXX)
cleanup() {
    rm -rf "$out"
}
trap cleanup EXIT

fortad_repo="$fortad_checkout"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -x "$fortad_repo/build/fo/bin/fortad"

mkdir -p "$out/exact" "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/port" "$out/mod"
compile_fixed() {
    local source=$1 label=$2
    set +e
    "$fc" "${fixed_flags[@]}" -c "$source" -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}
compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}
expected_refusal() {
    local label=$1 diagnostic=$2
    shift 2
    set +e
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    test "$status" -ne 0
    grep -Fq "$diagnostic" "$out/$label.stderr"
}

fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
test -x "$fortad"; test -x "$tapenade"

compile_fixed "$source_dir/program.f" exact_program
compile_fixed "$source_dir/program_d.f" exact_tangent
compile_fixed "$source_dir/program_b.f" exact_reverse
for label in exact_program exact_tangent exact_reverse; do test "$(cat "$out/$label.status")" = 0; done

(cd "$out/tapenade/parser" && "$tapenade" -p -root adj13bis -O . -o lh047 "$source_dir/program.f") >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -root adj13bis -O . -o lh047 "$source_dir/program.f") >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -root adj13bis -O . -o lh047 "$source_dir/program.f") >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
for generated in "$out/tapenade/parser/lh047_p.f" "$out/tapenade/forward/lh047_d.f" "$out/tapenade/reverse/lh047_b.f"; do test -s "$generated"; done
compile_fixed "$out/tapenade/parser/lh047_p.f" fresh_parser
compile_fixed "$out/tapenade/forward/lh047_d.f" fresh_tangent
compile_fixed "$out/tapenade/reverse/lh047_b.f" fresh_reverse
for label in fresh_parser fresh_tangent fresh_reverse; do test "$(cat "$out/$label.status")" = 0; done

expected_refusal exact_fortad_forward 'fortad: unsupported statement at line 5' \
    "$fortad" --mode forward --indep u,z,t --proc adj13bis --name lh047_exact_jvp \
    --module lh047_exact_jvp_ad --output "$out/exact/forward.f90" "$source_dir/program.f"
expected_refusal exact_fortad_reverse 'fortad: unsupported statement at line 5' \
    "$fortad" --mode reverse --indep u,z,t --dep t --proc adj13bis --name lh047_exact_vjp \
    --module lh047_exact_vjp_ad --output "$out/exact/reverse.f90" "$source_dir/program.f"
test ! -e "$out/exact/forward.f90"; test ! -e "$out/exact/reverse.f90"

"$fortad" jvp u,z,t,x1,x8,x9,x10,x11,y,v --proc set01_lh047 --name lh047_jvp \
    --module lh047_jvp_ad --output "$out/port/jvp.f90" "$case_dir/port.f90" \
    >"$out/port/jvp.stdout" 2>"$out/port/jvp.stderr"
"$fortad" vjp u,z,x1,x8,x9,x10,x11,y,v --dep t --proc set01_lh047 --name lh047_vjp \
    --module lh047_vjp_ad --output "$out/port/vjp.f90" "$case_dir/port.f90" \
    >"$out/port/vjp.stdout" 2>"$out/port/vjp.stderr"
test -s "$out/port/jvp.f90"; test -s "$out/port/vjp.f90"
compile_free "$case_dir/port.f90" port
compile_free "$case_dir/hand.f90" hand
compile_free "$out/port/jvp.f90" bounded_jvp
compile_free "$out/port/vjp.f90" bounded_vjp
test "$(cat "$out/port.status")" = 0; test "$(cat "$out/hand.status")" = 0
test "$(cat "$out/bounded_jvp.status")" = 0
test "$(cat "$out/bounded_vjp.status")" -ne 0
grep -Fq 'INTENT(IN)' "$out/bounded_vjp.stderr"
python3 "$case_dir/oracle.py" >"$out/python-oracle.txt"
grep -Fqx 'oracle_status: pass' "$out/python-oracle.txt"

compile_free "$case_dir/harness.f90" harness
test "$(cat "$out/harness.status")" = 0
"$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/port/harness" \
    "$out/port.o" "$out/hand.o" "$out/bounded_jvp.o" "$out/harness.o"
"$out/port/harness" >"$out/fortran-oracle.txt"
grep -Fqx 'oracle_status: pass' "$out/fortran-oracle.txt"

{
    printf 'case: Tapenade nonRegressions set01 lh047\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'entry_point: adj13bis(u,z,t); sub1(u,y2,z,v)\n'
    printf 'options: -p|-d-root-adj13bis|-b-root-adj13bis\n'
    printf 'modes: exact-forward=refused exact-reverse=refused bounded-forward=pass bounded-reverse=generated-compile-refusal\n'
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_strict_compile: program=%s tangent=%s reverse=%s\n' "$(cat "$out/exact_program.status")" "$(cat "$out/exact_tangent.status")" "$(cat "$out/exact_reverse.status")"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' "$(cat "$out/fresh_parser.status")" "$(cat "$out/fresh_tangent.status")" "$(cat "$out/fresh_reverse.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="unsupported statement at line 5 COMMON /cc/"\n' "$(cat "$out/exact_fortad_forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="unsupported statement at line 5 COMMON /cc/"\n' "$(cat "$out/exact_fortad_reverse.status")"
    printf 'fortad_bounded_forward: generation=pass strict_compile=%s\n' "$(cat "$out/bounded_jvp.status")"
    printf 'fortad_bounded_reverse: generation=pass strict_compile=expected-refusal diagnostic="dependent seed t_b has INTENT(IN)"\n'
    printf 'dependencies: COMMON /cc/, scalar-to-array actual mismatch, and v used before initialization\n'
    printf 'independent_oracle: hand JVP, central-difference sweep, and adjoint identity\n'
    cat "$out/python-oracle.txt"
    cat "$out/fortran-oracle.txt"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_d.f program_b.f program_d.msg program_b.msg)
} >"$result"
cat "$result"
