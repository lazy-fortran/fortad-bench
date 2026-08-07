#!/usr/bin/env bash
# Validate pinned Tapenade set01/lh069 with exact and bounded evidence.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=0e156041c1f92736c1e35f8164b37992c4c8d780
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors \
    -Wall -Wextra -Wimplicit-interface)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
    -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh069"

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_p.f program_d.f program_b.f program_dv.f \
    program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh069.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/port" "$out/mod"

compile_capture() {
    local source=$1 object=$2 status_file=$3 form=$4
    local -a flags
    if test "$form" = fixed; then
        flags=("${strict_fixed[@]}")
    else
        flags=("${strict_free[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" \
        >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
    printf '%s\n' "$status"
}

exact_program=$(compile_capture "$source_dir/program.f" "$out/exact/program.o" \
    "$out/exact/program.status" fixed)
exact_parser=$(compile_capture "$source_dir/program_p.f" "$out/exact/parser.o" \
    "$out/exact/parser.status" fixed)
exact_tangent=$(compile_capture "$source_dir/program_d.f" "$out/exact/tangent.o" \
    "$out/exact/tangent.status" fixed)
exact_reverse=$(compile_capture "$source_dir/program_b.f" "$out/exact/reverse.o" \
    "$out/exact/reverse.status" fixed)
exact_multi=$(compile_capture "$source_dir/program_dv.f" "$out/exact/multi.o" \
    "$out/exact/multi.status" fixed)
test "$exact_program" -eq 0
test "$exact_parser" -eq 0
test "$exact_tangent" -eq 0
test "$exact_reverse" -eq 0
test "$exact_multi" -ne 0
grep -Fq "DIFFSIZES.inc" "$out/exact/multi.o.stderr"

tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
test -x "$tapenade"
(cd "$out/tapenade/parser" && "$tapenade" -p -root loop2 -O . -o lh069 \
    "$source_dir/program.f") >"$out/tapenade/parser.stdout" 2>"$out/tapenade/parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -root loop2 -O . -o lh069 \
    "$source_dir/program.f") >"$out/tapenade/forward.stdout" 2>"$out/tapenade/forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -root loop2 -O . -o lh069 \
    "$source_dir/program.f") >"$out/tapenade/reverse.stdout" 2>"$out/tapenade/reverse.stderr"
for generated in "$out/tapenade/parser/lh069_p.f" \
    "$out/tapenade/forward/lh069_d.f" "$out/tapenade/reverse/lh069_b.f"; do
    test -s "$generated"
done
fresh_parser=$(compile_capture "$out/tapenade/parser/lh069_p.f" "$out/tapenade/parser.o" \
    "$out/tapenade/parser.status" fixed)
fresh_tangent=$(compile_capture "$out/tapenade/forward/lh069_d.f" "$out/tapenade/forward.o" \
    "$out/tapenade/forward.status" fixed)
fresh_reverse=$(compile_capture "$out/tapenade/reverse/lh069_b.f" "$out/tapenade/reverse.o" \
    "$out/tapenade/reverse.status" fixed)
test "$fresh_parser" -eq 0
test "$fresh_tangent" -eq 0
test "$fresh_reverse" -eq 0

fortad_bin=${FORTAD_BIN:-"$fortad_repo/build/fo/bin/fortad"}
if test ! -x "$fortad_bin"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
test -x "$fortad_bin"
set +e
"$fortad_bin" --mode forward --indep A,B --proc loop2 --name lh069_exact_jvp \
    --module lh069_exact_jvp_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f" >"$out/exact/forward.log" 2>&1
exact_fortad_forward=$?
"$fortad_bin" --mode reverse --indep A,B --dep A,B --proc loop2 --name lh069_exact_vjp \
    --module lh069_exact_vjp_mod --output "$out/exact/reverse.f90" \
    "$source_dir/program.f" >"$out/exact/reverse.log" 2>&1
exact_fortad_reverse=$?
set -e
test "$exact_fortad_forward" -ne 0
test "$exact_fortad_reverse" -ne 0
grep -Fq "unsupported statement at line 6" "$out/exact/forward.log"
grep -Fq "unsupported statement at line 6" "$out/exact/reverse.log"
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"

indep=a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10
"$fortad_bin" jvp "$indep" --proc set01_lh069 --name lh069_jvp \
    --module lh069_jvp_mod --output "$out/port/jvp.f90" "$case_dir/port.f90" \
    >"$out/port/jvp.log" 2>&1
"$fortad_bin" vjp "$indep" --dep ao7 --proc set01_lh069 --name lh069_ao7_vjp \
    --module lh069_ao7_vjp_mod --output "$out/port/ao7.f90" "$case_dir/port.f90" \
    >"$out/port/ao7.log" 2>&1
"$fortad_bin" vjp "$indep" --dep bo5 --proc set01_lh069 --name lh069_bo5_vjp \
    --module lh069_bo5_vjp_mod --output "$out/port/bo5.f90" "$case_dir/port.f90" \
    >"$out/port/bo5.log" 2>&1
for generated in "$out/port/jvp.f90" "$out/port/ao7.f90" "$out/port/bo5.f90"; do
    test -s "$generated"
done

port_status=$(compile_capture "$case_dir/port.f90" "$out/port/port.o" \
    "$out/port/port.status" free)
hand_status=$(compile_capture "$case_dir/hand.f90" "$out/port/hand.o" \
    "$out/port/hand.status" free)
jvp_status=$(compile_capture "$out/port/jvp.f90" "$out/port/jvp.o" \
    "$out/port/jvp.status" free)
ao7_status=$(compile_capture "$out/port/ao7.f90" "$out/port/ao7.o" \
    "$out/port/ao7.status" free)
bo5_status=$(compile_capture "$out/port/bo5.f90" "$out/port/bo5.o" \
    "$out/port/bo5.status" free)
harness_status=$(compile_capture "$case_dir/harness.f90" "$out/port/harness.o" \
    "$out/port/harness.status" free)
test "$port_status" -eq 0
test "$hand_status" -eq 0
test "$jvp_status" -eq 0
test "$ao7_status" -eq 0
test "$bo5_status" -eq 0
test "$harness_status" -eq 0
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/port/harness" \
    "$out/port/port.o" "$out/port/hand.o" "$out/port/jvp.o" \
    "$out/port/ao7.o" "$out/port/bo5.o" "$out/port/harness.o"
python3 "$case_dir/oracle.py" >"$out/oracle.txt"
"$out/port/harness" >"$out/port/run.txt"
grep -Fq 'oracle_status: pass' "$out/oracle.txt"
grep -Fq 'harness_status: pass' "$out/port/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh069\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_strict_compile: program=%s parser=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$exact_program" "$exact_parser" "$exact_tangent" "$exact_reverse" "$exact_multi"
    printf 'upstream_stored_references: parser=program_p.f tangent=program_d.f reverse=program_b.f multidirectional=program_dv.f\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser" "$fresh_tangent" "$fresh_reverse"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="unsupported statement at line 6"\n' \
        "$exact_fortad_forward"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="unsupported statement at line 6"\n' \
        "$exact_fortad_reverse"
    printf 'fortad_bounded_forward_generation: pass\n'
    printf 'fortad_bounded_forward_strict_compile: %s\n' "$jvp_status"
    printf 'fortad_bounded_reverse_generation: ao7=pass bo5=pass\n'
    printf 'fortad_bounded_reverse_strict_compile: ao7=%s bo5=%s\n' "$ao7_status" "$bo5_status"
    printf 'bounded_port_precondition: n=10; 4*a4>a8 before copy; 4*a4<=b8 after one copy; one terminating iteration\n'
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, adjoint identity, and compiled harness\n'
    cat "$out/oracle.txt"
    cat "$out/port/run.txt"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh069/manifest.toml \
        cases/tapenade-set01/lh069/notes.md cases/tapenade-set01/lh069/port.f90 \
        cases/tapenade-set01/lh069/hand.f90 cases/tapenade-set01/lh069/harness.f90 \
        cases/tapenade-set01/lh069/oracle.py cases/tapenade-set01/lh069/run.sh \
        cases/tapenade-set01/lh069/test_contract.py)
} >"$result"
cat "$result"
