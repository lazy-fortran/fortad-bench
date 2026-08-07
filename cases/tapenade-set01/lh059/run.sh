#!/usr/bin/env bash
# Reproducible exact, fresh-generation, FortAD, and bounded evidence probe.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
result="$case_dir/result.txt"
required_fortad_commit=0e156041c1f92736c1e35f8164b37992c4c8d780
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh059"

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for message in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -e "$source_dir/$message"
done

fortad="$fortad_repo/build/fo/bin/fortad"
if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >"/var/tmp/fortad-bench-lh059-fortad-build.log" 2>&1
fi
test -x "$fortad"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh059.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" \
    "$out/bounded" "$out/mod"

compile_fixed() {
    local source=$1 object=$2 status_file=$3
    set +e
    "$fc" "${fixed[@]}" -c "$source" -o "$object" \
        >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
    printf '%s\n' "$status"
}

exact_primal=$(compile_fixed "$source_dir/program.f" "$out/exact_primal.o" "$out/exact_primal.status")
exact_parser=$(compile_fixed "$source_dir/program_p.f" "$out/exact_parser.o" "$out/exact_parser.status")
exact_tangent=$(compile_fixed "$source_dir/program_d.f" "$out/exact_tangent.o" "$out/exact_tangent.status")
exact_reverse=$(compile_fixed "$source_dir/program_b.f" "$out/exact_reverse.o" "$out/exact_reverse.status")
exact_multidirectional=$(compile_fixed "$source_dir/program_dv.f" "$out/exact_multidirectional.o" "$out/exact_multidirectional.status")
test "$exact_primal" -eq 0
test "$exact_parser" -eq 0
test "$exact_tangent" -eq 0
test "$exact_reverse" -ne 0
test "$exact_multidirectional" -ne 0
grep -Fq 'Nonstandard type declaration INTEGER*4' "$out/exact_reverse.o.stderr"
grep -Fq 'DIFFSIZES.inc' "$out/exact_multidirectional.o.stderr"

tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
test -x "$tapenade"
(cd "$out/tapenade/parser" && "$tapenade" -p -O . -o lh059 "$source_dir/program.f") \
    >"$out/tapenade/parser/generation.stdout" 2>"$out/tapenade/parser/generation.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -root sub2 -O . -o lh059 "$source_dir/program.f") \
    >"$out/tapenade/forward/generation.stdout" 2>"$out/tapenade/forward/generation.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -root sub2 -O . -o lh059 "$source_dir/program.f") \
    >"$out/tapenade/reverse/generation.stdout" 2>"$out/tapenade/reverse/generation.stderr"
test -s "$out/tapenade/parser/lh059_p.f"
test -s "$out/tapenade/forward/lh059_d.f"
test -s "$out/tapenade/reverse/lh059_b.f"
fresh_parser=$(compile_fixed "$out/tapenade/parser/lh059_p.f" "$out/fresh_parser.o" "$out/fresh_parser.status")
fresh_tangent=$(compile_fixed "$out/tapenade/forward/lh059_d.f" "$out/fresh_tangent.o" "$out/fresh_tangent.status")
fresh_reverse=$(compile_fixed "$out/tapenade/reverse/lh059_b.f" "$out/fresh_reverse.o" "$out/fresh_reverse.status")
test "$fresh_parser" -eq 0
test "$fresh_tangent" -eq 0
test "$fresh_reverse" -ne 0
grep -Fq 'Nonstandard type declaration INTEGER*4' "$out/fresh_reverse.o.stderr"

set +e
"$fortad" --mode forward --indep T,U --proc sub2 --name lh059_exact_jvp \
    --module lh059_exact_jvp_mod --output "$out/exact_forward.f90" "$source_dir/program.f" \
    >"$out/exact_forward.stdout" 2>"$out/exact_forward.stderr"
exact_fortad_forward=$?
"$fortad" --mode reverse --indep T,U --dep T --proc sub2 --name lh059_exact_vjp \
    --module lh059_exact_vjp_mod --output "$out/exact_reverse.f90" "$source_dir/program.f" \
    >"$out/exact_reverse.stdout" 2>"$out/exact_reverse.stderr"
exact_fortad_reverse=$?
set -e
test "$exact_fortad_forward" -ne 0
test "$exact_fortad_reverse" -ne 0
test ! -e "$out/exact_forward.f90"
test ! -e "$out/exact_reverse.f90"
grep -Fq 'Unrecognized statement: 5 i =' "$out/exact_forward.stderr"
grep -Fq 'Unrecognized statement: 5 i =' "$out/exact_reverse.stderr"

"$fortad" --mode forward --indep t,u --proc set01_lh059 --name lh059_forward \
    --module lh059_forward_mod --output "$out/bounded/forward.f90" "$case_dir/port.f90" \
    >"$out/bounded/forward.stdout" 2>"$out/bounded/forward.stderr"
test -s "$out/bounded/forward.f90"

bounded_reverse_status_t=0
bounded_reverse_status_u=0
for dep in t u; do
    set +e
    "$fortad" --mode reverse --indep t,u --dep "$dep" --proc set01_lh059 \
        --name "lh059_${dep}_reverse" --module "lh059_${dep}_reverse_mod" \
        --output "$out/bounded/${dep}_reverse.f90" "$case_dir/port.f90" \
        >"$out/bounded/${dep}_reverse.stdout" 2>"$out/bounded/${dep}_reverse.stderr"
    status=$?
    set -e
    if test "$dep" = t; then bounded_reverse_status_t=$status; else bounded_reverse_status_u=$status; fi
    test "$status" -ne 0
    test ! -e "$out/bounded/${dep}_reverse.f90"
    grep -Fq 'branch inside a loop needs control-flow reversal' "$out/bounded/${dep}_reverse.stderr"
done

compile_free() {
    local source=$1 object=$2
    "$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" -o "$object" \
        >"$object.stdout" 2>"$object.stderr"
}
compile_free "$case_dir/port.f90" "$out/bounded/port.o"
compile_free "$case_dir/hand.f90" "$out/bounded/hand.o"
compile_free "$out/bounded/forward.f90" "$out/bounded/forward.o"
compile_free "$case_dir/harness.f90" "$out/bounded/harness.o"
"$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bounded/harness" \
    "$out/bounded/port.o" "$out/bounded/hand.o" "$out/bounded/forward.o" "$out/bounded/harness.o"
"$out/bounded/harness" >"$out/bounded/harness.log"
python3 "$case_dir/oracle.py" >"$out/oracle.log"
grep -Fq 'harness_status: pass' "$out/bounded/harness.log"
grep -Fq 'oracle_status: pass' "$out/oracle.log"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh059\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${fixed[*]}"
    printf 'strict_free_flags: %s\n' "${free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_strict_compile: primal=%s parser_reference=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$exact_primal" "$exact_parser" "$exact_tangent" "$exact_reverse" "$exact_multidirectional"
    printf 'stored_diagnostics: reverse=nonstandard-INTEGER*4 multidirectional=missing-DIFFSIZES.inc\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass root=sub2\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser" "$fresh_tangent" "$fresh_reverse"
    printf 'tapenade_fresh_diagnostics: reverse=nonstandard-INTEGER*4\n'
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="Unrecognized statement: 5 i ="\n' "$exact_fortad_forward"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="Unrecognized statement: 5 i ="\n' "$exact_fortad_reverse"
    printf 'fortad_bounded_forward: pass-transform-compile-runtime status=0\n'
    printf 'fortad_bounded_reverse: expected-refusal t_status=%s u_status=%s diagnostic="branch inside a loop needs control-flow reversal"\n' \
        "$bounded_reverse_status_t" "$bounded_reverse_status_u"
    printf 'independent_oracle: hand JVP, central-difference sweep, and adjoint identity\n'
    cat "$out/oracle.log"
    cat "$out/bounded/harness.log"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh059/manifest.toml \
        cases/tapenade-set01/lh059/notes.md cases/tapenade-set01/lh059/port.f90 \
        cases/tapenade-set01/lh059/hand.f90 cases/tapenade-set01/lh059/harness.f90 \
        cases/tapenade-set01/lh059/oracle.py cases/tapenade-set01/lh059/run.sh \
        cases/tapenade-set01/lh059/test_contract.py)
} >"$result"
cat "$result"
