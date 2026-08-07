#!/usr/bin/env bash
# Reproducible exact, fresh-generation, FortAD, and bounded evidence probe.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_candidate=${FORTAD_REPO:-"$root/../fortad"}
tapenade_candidate=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if [[ ! -e "$fortad_candidate/.git" && -e /mnt/storage/code/lazy-fortran/fortad/.git ]]; then
    fortad_candidate=/mnt/storage/code/lazy-fortran/fortad
fi
fortad_repo=$(cd "$fortad_candidate" && pwd)
tapenade_repo=$(cd "$tapenade_candidate" && pwd)
result="$case_dir/result.txt"
required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh076"

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for message in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -f "$source_dir/$message"
done

fortad="$fortad_repo/build/fo/bin/fortad"
if test ! -x "$fortad"; then
    command -v fo >/dev/null
    (cd "$fortad_repo" && fo build) >"/var/tmp/fortad-bench-lh076-fortad-build.log" 2>&1
fi
test -x "$fortad"
tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"/var/tmp/fortad-bench-lh076-tapenade-build.log" 2>&1
fi
test -x "$tapenade"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh076.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/exact" "$out/bounded" "$out/mod"

compile_fixed() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_fixed[@]}" -I"$source_dir" -J"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    printf '%s\n' "$status"
}

compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    printf '%s\n' "$status"
}

exact_primal=$(compile_fixed "$source_dir/program.f" upstream_primal)
exact_parser=$(compile_fixed "$source_dir/program_p.f" upstream_parser)
exact_tangent=$(compile_fixed "$source_dir/program_d.f" upstream_tangent)
exact_reverse=$(compile_fixed "$source_dir/program_b.f" upstream_reverse)
exact_multidirectional=$(compile_fixed "$source_dir/program_dv.f" upstream_multidirectional)
test "$exact_primal" -eq 1
test "$exact_parser" -eq 1
test "$exact_tangent" -eq 1
test "$exact_reverse" -eq 1
test "$exact_multidirectional" -eq 1
for label in upstream_primal upstream_parser upstream_tangent upstream_reverse; do
    grep -Fq 'Nonstandard type declaration REAL*8' "$out/$label.stderr"
done
grep -Fq 'Cannot open included file' "$out/upstream_multidirectional.stderr"
grep -Fq 'DIFFSIZES.inc' "$out/upstream_multidirectional.stderr"

(
    cd "$out/tapenade/parser"
    "$tapenade" -p -root onegvert -O . -o lh076 "$source_dir/program.f"
) >"$out/tapenade/parser/generation.stdout" 2>"$out/tapenade/parser/generation.stderr"
(
    cd "$out/tapenade/forward"
    "$tapenade" -d -root onegvert -O . -o lh076 "$source_dir/program.f"
) >"$out/tapenade/forward/generation.stdout" 2>"$out/tapenade/forward/generation.stderr"
(
    cd "$out/tapenade/reverse"
    "$tapenade" -b -root onegvert -O . -o lh076 "$source_dir/program.f"
) >"$out/tapenade/reverse/generation.stdout" 2>"$out/tapenade/reverse/generation.stderr"
for generated in "$out/tapenade/parser/lh076_p.f" \
                 "$out/tapenade/forward/lh076_d.f" \
                 "$out/tapenade/reverse/lh076_b.f"; do
    test -s "$generated"
done
fresh_parser=$(compile_fixed "$out/tapenade/parser/lh076_p.f" fresh_parser)
fresh_tangent=$(compile_fixed "$out/tapenade/forward/lh076_d.f" fresh_tangent)
fresh_reverse=$(compile_fixed "$out/tapenade/reverse/lh076_b.f" fresh_reverse)
test "$fresh_parser" -eq 1
test "$fresh_tangent" -eq 1
test "$fresh_reverse" -eq 1
for label in fresh_parser fresh_tangent fresh_reverse; do
    grep -Fq 'Nonstandard type declaration REAL*8' "$out/$label.stderr"
done

set +e
"$fortad" --mode forward --indep pin4 --proc onegvert \
    --name lh076_exact_forward --module lh076_exact_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f" \
    >"$out/exact/forward.stdout" 2>"$out/exact/forward.stderr"
exact_fortad_forward=$?
"$fortad" --mode reverse --indep pin4 --dep emipint --proc onegvert \
    --name lh076_exact_reverse --module lh076_exact_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f" \
    >"$out/exact/reverse.stdout" 2>"$out/exact/reverse.stderr"
exact_fortad_reverse=$?
set -e
test "$exact_fortad_forward" -ne 0
test "$exact_fortad_reverse" -ne 0
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
grep -Fq "independent 'pin4' is not declared in onegvert" "$out/exact/forward.stderr"
grep -Fq "dependent 'emipint' is not declared in onegvert" "$out/exact/reverse.stderr"

"$fortad" --mode forward --indep pin4 --proc set01_lh076 \
    --name lh076_jvp --module lh076_jvp_mod \
    --output "$out/bounded/jvp.f90" "$case_dir/port.f90" \
    >"$out/bounded/jvp.stdout" 2>"$out/bounded/jvp.stderr"
test -s "$out/bounded/jvp.f90"
set +e
"$fortad" --mode reverse --indep pin4 --dep emipint --proc set01_lh076 \
    --name lh076_vjp --module lh076_vjp_mod \
    --output "$out/bounded/vjp.f90" "$case_dir/port.f90" \
    >"$out/bounded/vjp.stdout" 2>"$out/bounded/vjp.stderr"
bounded_reverse=$?
set -e
test "$bounded_reverse" -ne 0
test ! -e "$out/bounded/vjp.f90"
grep -Fq 'complex' "$out/bounded/vjp.stderr"

port_status=$(compile_free "$case_dir/port.f90" bounded_port)
hand_status=$(compile_free "$case_dir/hand.f90" bounded_hand)
jvp_status=$(compile_free "$out/bounded/jvp.f90" bounded_jvp)
harness_status=$(compile_free "$case_dir/harness.f90" bounded_harness)
test "$port_status" -eq 0
test "$hand_status" -eq 0
test "$jvp_status" -eq 0
test "$harness_status" -eq 0
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bounded/harness" \
    "$out/bounded_port.o" "$out/bounded_hand.o" "$out/bounded_jvp.o" \
    "$out/bounded_harness.o" >"$out/bounded/link.stdout" 2>"$out/bounded/link.stderr"
"$out/bounded/harness" >"$out/bounded/harness.log"
python3 "$case_dir/oracle.py" >"$out/oracle.log"
grep -Fq 'harness_status: pass' "$out/bounded/harness.log"
grep -Fq 'oracle_status: pass' "$out/oracle.log"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh076\n'
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
    printf 'upstream_exact_strict_compile: primal=%s parser=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$exact_primal" "$exact_parser" "$exact_tangent" "$exact_reverse" "$exact_multidirectional"
    printf 'upstream_stored_diagnostics: primal=legacy-REAL*8-COMPLEX*16 parser=legacy-REAL*8-COMPLEX*16 tangent=legacy-REAL*8-COMPLEX*16 reverse=legacy-REAL*8-COMPLEX*16 multidirectional=missing-DIFFSIZES.inc\n'
    printf 'tapenade_options: parser=-p/-root onegvert tangent=-d/-root onegvert reverse=-b/-root onegvert\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser" "$fresh_tangent" "$fresh_reverse"
    printf 'tapenade_fresh_diagnostics: parser=tangent=reverse=legacy-REAL*8-COMPLEX*16\n'
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="independent pin4 is not declared in onegvert"\n' "$exact_fortad_forward"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="dependent emipint is not declared in onegvert"\n' "$exact_fortad_reverse"
    printf 'fortad_bounded_forward: pass-transform-compile-runtime transform=pass compile=%s runtime=pass\n' "$jvp_status"
    printf 'fortad_bounded_reverse: expected-refusal status=%s diagnostic="active complex-output reverse boundary"\n' "$bounded_reverse"
    printf 'bounded_scope: standard real(8)/complex(8) spelling with explicit intents; scalar-to-complex map only\n'
    printf 'independent_oracle: hand complex JVP/VJP, central-difference sweep, real-coordinate adjoint identity\n'
    cat "$out/oracle.log"
    cat "$out/bounded/harness.log"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh076_p.f lh076_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh076_d.f lh076_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh076_b.f lh076_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md port.f90 hand.f90 harness.f90 \
        oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
