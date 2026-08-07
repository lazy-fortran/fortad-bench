#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh078 invalid-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=7adc75030db3fa4422339d82d2725ae29ee13dac
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/lh078
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh078.XXXXXX)

# The requested FortAD revision is an ancestor of the caller's current
# worktree in some bench runs.  Build that pinned tree in the runner's
# temporary directory instead of changing the shared FortAD checkout.
if test "$(git -C "$fortad_repo" rev-parse HEAD)" != "$required_fortad_commit"; then
    pinned_root="$out/fortad-$required_fortad_commit"
    mkdir -p "$pinned_root"
    git -C "$fortad_repo" archive "$required_fortad_commit" | tar -xf - -C "$pinned_root"
    ln -s "$(dirname "$fortad_repo")/fortfront" "$out/fortfront"
    ln -s "$(dirname "$fortad_repo")/fortgen" "$out/fortgen"
    (cd "$pinned_root" && fo build) >"$out/fortad-build.log" 2>&1
    fortad="$pinned_root/build/fo/bin/fortad"
fi

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"

for source in program.f program_p.f program_p.msg program_d.f program_d.msg \
    program_b.f program_b.msg program_dv.f program_dv.msg; do
    test -s "$source_dir/$source"
done

mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/fresh/vector" "$out/fortad/check" \
    "$out/fortad/forward"
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none \
    -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none \
    -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_fixed() {
    local label=$1
    local source=$2
    run_status "compile-$label" "$fc" "${strict_fixed[@]}" "$source" \
        -o "$out/$label.o"
}

compile_free() {
    local label=$1
    local source=$2
    run_status "compile-$label" "$fc" "${strict_free[@]}" "$source" \
        -o "$out/$label.o"
}

fresh_suffix() {
    case "$1" in
        parser) echo p ;;
        forward) echo d ;;
        reverse) echo b ;;
        vector) echo dv ;;
    esac
}

# Contract 1: exact source and every stored Fortran reference reject strict compilation.
for source in program program_p program_d program_b program_dv; do
    compile_fixed "exact-$source" "$source_dir/$source.f"
    test "$(cat "$out/compile-exact-$source.status")" -ne 0
done
grep -Fq "Syntax error in SUBROUTINE statement" "$out/compile-exact-program.stderr"
grep -Fq "REAL*8" "$out/compile-exact-program.stderr"
for source in program_p program_d program_b; do
    grep -Fq "REAL*8" "$out/compile-exact-$source.stderr"
done
grep -Fq "Cannot open included file" "$out/compile-exact-program_dv.stderr"

# Contract 2: fresh pinned Tapenade generation succeeds, but all products fail strict compilation.
run_status tapenade-parser "$tapenade" -p -O "$out/fresh/parser" -o lh078 \
    "$source_dir/program.f"
run_status tapenade-forward "$tapenade" -d -root testPower \
    -O "$out/fresh/forward" -o lh078 "$source_dir/program.f"
run_status tapenade-reverse "$tapenade" -b -root testPower \
    -O "$out/fresh/reverse" -o lh078 "$source_dir/program.f"
run_status tapenade-vector "$tapenade" -d -root testPower -multi \
    -O "$out/fresh/vector" -o lh078 "$source_dir/program.f"
for mode in parser forward reverse vector; do
    suffix=$(fresh_suffix "$mode")
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
    test -s "$out/fresh/$mode/lh078_${suffix}.f"
    grep -Fq "(DF03) variable c[3] is used before initialized" \
        "$out/fresh/$mode/lh078_${suffix}.msg"
    compile_fixed "fresh-$mode" "$out/fresh/$mode/lh078_${suffix}.f"
    test "$(cat "$out/compile-fresh-$mode.status")" -ne 0
done
grep -Fq "Cannot open included file" "$out/compile-fresh-vector.stderr"

# Contract 3: exact FortAD parser/forward/reverse behavior plus the independent oracle.
oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"
run_status fortad-check "$fortad" check --output "$out/fortad/check/roundtrip.f90" \
    "$source_dir/program.f"
test "$(cat "$out/fortad-check.status")" -eq 0
test -s "$out/fortad/check/roundtrip.f90"
compile_free fortad-check "$out/fortad/check/roundtrip.f90"
test "$(cat "$out/compile-fortad-check.status")" -ne 0
grep -Fq "has no IMPLICIT type" "$out/compile-fortad-check.stderr"
run_status fortad-forward "$fortad" --mode forward --indep x --dep r --proc testPower \
    --name lh078_jvp --module lh078_jvp_mod --output "$out/fortad/forward/product.f90" \
    "$source_dir/program.f"
test "$(cat "$out/fortad-forward.status")" -eq 0
test -s "$out/fortad/forward/product.f90"
compile_free fortad-forward "$out/fortad/forward/product.f90"
test "$(cat "$out/compile-fortad-forward.status")" -ne 0
grep -Fq "has no IMPLICIT type" "$out/compile-fortad-forward.stderr"
run_status fortad-reverse "$fortad" --mode reverse --indep x --dep r --proc testPower \
    --name lh078_vjp --module lh078_vjp_mod --output "$out/fortad/reverse.f90" \
    "$source_dir/program.f"
test "$(cat "$out/fortad-reverse.status")" -ne 0
grep -Fq "assignment to undeclared 'r8(4)'" "$out/fortad-reverse.stdout" "$out/fortad-reverse.stderr"
test ! -e "$out/fortad/reverse.f90"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set01 lh078\n'
    printf 'classification: unsupported-invalid-upstream-fortran\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'fortad_checkout: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'fortad_commit: %s\n' "$required_fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: testPower(x,y,r,x8,y8,r8)\n'
    printf 'selected_entry_points: testPower\n'
    printf 'tapenade_options: parser=-p forward=-d/-root testPower reverse=-b/-root testPower multidirectional=-d/-root testPower/-multi\n'
    printf 'upstream_exact_strict_compile: expected-refusal status=%s\n' "$(cat "$out/compile-exact-program.status")"
    printf 'stored_reference_strict_compile: parser=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$(cat "$out/compile-exact-program_p.status")" "$(cat "$out/compile-exact-program_d.status")" \
        "$(cat "$out/compile-exact-program_b.status")" "$(cat "$out/compile-exact-program_dv.status")"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s multidirectional=%s\n' \
        "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-forward.status")" \
        "$(cat "$out/tapenade-reverse.status")" "$(cat "$out/tapenade-vector.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s multidirectional=%s\n' \
        "$(cat "$out/compile-fresh-parser.status")" "$(cat "$out/compile-fresh-forward.status")" \
        "$(cat "$out/compile-fresh-reverse.status")" "$(cat "$out/compile-fresh-vector.status")"
    printf 'tapenade_diagnostics: DF03 c[1] c[3] uninitialized in all modes\n'
    printf 'fortad_check: pass-generation strict-compile-refusal status=%s\n' "$(cat "$out/fortad-check.status")"
    printf 'fortad_forward: pass-generation strict-compile-refusal status=%s\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_reverse: expected-refusal-undeclared-r8 status=%s\n' "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: exact invalid-brace REAL*8 uninitialized-c missing-DIFFSIZES inventory\n'
    printf '%s\n' "$oracle_output"
    printf 'port_result: not-applicable-invalid-upstream\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_p.f "$source_rel"/program_p.msg \
        "$source_rel"/program_d.f "$source_rel"/program_d.msg "$source_rel"/program_b.f "$source_rel"/program_b.msg \
        "$source_rel"/program_dv.f "$source_rel"/program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    for mode in parser forward reverse vector; do
        suffix=$(fresh_suffix "$mode")
        (cd "$out/fresh/$mode" && sha256sum "lh078_${suffix}.f" "lh078_${suffix}.msg")
    done
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh078/manifest.toml \
        cases/tapenade-set01/lh078/notes.md cases/tapenade-set01/lh078/oracle.py \
        cases/tapenade-set01/lh078/run.sh cases/tapenade-set01/lh078/test_contract.py)
} >"$result"
cat "$result"
