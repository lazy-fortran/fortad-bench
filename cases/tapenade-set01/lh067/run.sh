#!/usr/bin/env bash
# Reproducible exact, fresh-generation, FortAD, and bounded evidence probe.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_candidate=${FORTAD_REPO:-"$root/../fortad"}
tapenade_candidate=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if [[ ! -d "$fortad_candidate/.git" && ! -f "$fortad_candidate/.git" && \
      -d /home/ert/code/lazy-fortran/fortad/.git ]]; then
    fortad_candidate=/home/ert/code/lazy-fortran/fortad
fi
if [[ ! -d "$tapenade_candidate/.git" && ! -f "$tapenade_candidate/.git" && \
      -d /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git ]]; then
    tapenade_candidate=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_repo=$(cd "$fortad_candidate" && pwd)
tapenade_repo=$(cd "$tapenade_candidate" && pwd)
result="$case_dir/result.txt"
required_fortad_commit=0e156041c1f92736c1e35f8164b37992c4c8d780
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)
free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2
    -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh067"

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
if test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"; then
    fortad_worktree=clean
else
    fortad_worktree=dirty-preserved-user-changes
fi
for source in program.f program_p.f program_d.f program_b.f program_dv.f \
              program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -s "$source_dir/$source"
done

fortad="$fortad_repo/build/fo/bin/fortad"
if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >"/var/tmp/fortad-bench-lh067-fortad-build.log" 2>&1
fi
test -x "$fortad"
tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"/var/tmp/fortad-bench-lh067-tapenade-build.log" 2>&1
fi
test -x "$tapenade"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh067.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/bounded" "$out/mod"

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

compile_free() {
    local source=$1 object=$2 status_file=$3
    set +e
    "$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" -o "$object" \
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
test "$exact_parser" -ne 0
test "$exact_tangent" -ne 0
test "$exact_reverse" -ne 0
test "$exact_multidirectional" -ne 0
for label in exact_parser exact_tangent exact_reverse; do
    grep -Fq 'Symbol ‘nfic12’' "$out/${label}.o.stderr"
done
grep -Fq 'Cannot open included file' "$out/exact_multidirectional.o.stderr"

(
    cd "$out/tapenade/parser"
    "$tapenade" -p -root read7 -O . -o lh067 "$source_dir/program.f"
) >"$out/tapenade/parser/generation.stdout" 2>"$out/tapenade/parser/generation.stderr"
(
    cd "$out/tapenade/forward"
    "$tapenade" -d -root read7 -O . -o lh067 "$source_dir/program.f"
) >"$out/tapenade/forward/generation.stdout" 2>"$out/tapenade/forward/generation.stderr"
(
    cd "$out/tapenade/reverse"
    "$tapenade" -b -root read7 -O . -o lh067 "$source_dir/program.f"
) >"$out/tapenade/reverse/generation.stdout" 2>"$out/tapenade/reverse/generation.stderr"
test -s "$out/tapenade/parser/lh067_p.f"
test -s "$out/tapenade/forward/lh067_d.f"
test -s "$out/tapenade/reverse/lh067_b.f"
fresh_parser=$(compile_fixed "$out/tapenade/parser/lh067_p.f" "$out/fresh_parser.o" "$out/fresh_parser.status")
fresh_tangent=$(compile_fixed "$out/tapenade/forward/lh067_d.f" "$out/fresh_tangent.o" "$out/fresh_tangent.status")
fresh_reverse=$(compile_fixed "$out/tapenade/reverse/lh067_b.f" "$out/fresh_reverse.o" "$out/fresh_reverse.status")
for status in "$fresh_parser" "$fresh_tangent" "$fresh_reverse"; do
    test "$status" -ne 0
done
for label in fresh_parser fresh_tangent fresh_reverse; do
    grep -Fq 'Symbol ‘nfic12’' "$out/${label}.o.stderr"
done

set +e
"$fortad" --mode forward --indep z --dep read7 --proc read7 \
    --name lh067_exact_forward --module lh067_exact_forward_mod \
    --output "$out/exact_forward.f90" "$source_dir/program.f" \
    >"$out/exact_forward.log" 2>&1
exact_fortad_forward=$?
"$fortad" --mode reverse --indep z --dep read7 --proc read7 \
    --name lh067_exact_reverse --module lh067_exact_reverse_mod \
    --output "$out/exact_reverse.f90" "$source_dir/program.f" \
    >"$out/exact_reverse.log" 2>&1
exact_fortad_reverse=$?
set -e
# The forward CLI returns zero but its READ diagnostic is followed by an
# unusable empty-argument procedure.  Treat that as an exact refusal and test
# both the diagnostic and the independent strict compile failure.
test "$exact_fortad_forward" -eq 0
test -s "$out/exact_forward.f90"
grep -Fq "Expected ')' after read unit and format" "$out/exact_forward.log"
exact_forward_compile=$(compile_free "$out/exact_forward.f90" "$out/exact_forward.o" "$out/exact_forward_compile.status")
test "$exact_forward_compile" -ne 0
test "$exact_fortad_reverse" -ne 0
grep -Fq "dependent 'read7' is not declared in read7" "$out/exact_reverse.log"
test ! -e "$out/exact_reverse.f90"

"$fortad" --mode forward --indep z --proc set01_lh067 \
    --name lh067_forward --module lh067_forward_mod \
    --output "$out/bounded/forward.f90" "$case_dir/port.f90" \
    >"$out/bounded/forward.stdout" 2>"$out/bounded/forward.stderr"
"$fortad" --mode reverse --indep z --dep read7 --proc set01_lh067 \
    --name lh067_reverse --module lh067_reverse_mod \
    --output "$out/bounded/reverse.f90" "$case_dir/port.f90" \
    >"$out/bounded/reverse.stdout" 2>"$out/bounded/reverse.stderr"
test -s "$out/bounded/forward.f90"
test -s "$out/bounded/reverse.f90"

compile_free "$case_dir/port.f90" "$out/bounded/port.o" "$out/bounded/port.status" >/dev/null
compile_free "$case_dir/hand.f90" "$out/bounded/hand.o" "$out/bounded/hand.status" >/dev/null
compile_free "$out/bounded/forward.f90" "$out/bounded/forward.o" "$out/bounded/forward.status" >/dev/null
compile_free "$out/bounded/reverse.f90" "$out/bounded/reverse.o" "$out/bounded/reverse.status" >/dev/null
compile_free "$case_dir/harness.f90" "$out/bounded/harness.o" "$out/bounded/harness.status" >/dev/null
"$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bounded/harness" \
    "$out/bounded/port.o" "$out/bounded/hand.o" "$out/bounded/forward.o" \
    "$out/bounded/reverse.o" "$out/bounded/harness.o" \
    >"$out/bounded/link.stdout" 2>"$out/bounded/link.stderr"
"$out/bounded/harness" >"$out/bounded/harness.log"
python3 "$case_dir/oracle.py" >"$out/oracle.log"
grep -Fq 'harness_status: pass' "$out/bounded/harness.log"
grep -Fq 'oracle_status: pass' "$out/oracle.log"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh067\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${fixed[*]}"
    printf 'strict_free_flags: %s\n' "${free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_strict_compile: primal=%s parser_reference=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$exact_primal" "$exact_parser" "$exact_tangent" "$exact_reverse" "$exact_multidirectional"
    printf 'stored_diagnostics: parser=tangent=reverse=undeclared-nfic12 multidirectional=missing-DIFFSIZES.inc\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass root=read7\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser" "$fresh_tangent" "$fresh_reverse"
    printf 'tapenade_fresh_diagnostics: parser=tangent=reverse=undeclared-nfic12\n'
    printf 'fortad_exact_forward: expected-refusal exit=%s diagnostic="Expected ) after read unit and format" generated-compile=%s\n' \
        "$exact_fortad_forward" "$exact_forward_compile"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="dependent read7 is not declared in read7"\n' \
        "$exact_fortad_reverse"
    printf 'fortad_bounded_forward: pass-transform-compile-runtime status=0\n'
    printf 'fortad_bounded_reverse: pass-transform-compile-runtime status=0\n'
    printf 'bounded_scope: successful-read path with 1 < z < 2; error/end branches intentionally not defined\n'
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/oracle.log"
    cat "$out/bounded/harness.log"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh067/manifest.toml \
        cases/tapenade-set01/lh067/notes.md cases/tapenade-set01/lh067/port.f90 \
        cases/tapenade-set01/lh067/hand.f90 cases/tapenade-set01/lh067/harness.f90 \
        cases/tapenade-set01/lh067/oracle.py cases/tapenade-set01/lh067/run.sh \
        cases/tapenade-set01/lh067/test_contract.py)
} >"$result"
cat "$result"
