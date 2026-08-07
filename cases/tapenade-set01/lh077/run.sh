#!/usr/bin/env bash
# Validate pinned Tapenade set01/lh077 with exact, fresh, and bounded evidence.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_checkout/.git" && test -e /mnt/storage/code/lazy-fortran/fortad/.git; then
    fortad_checkout=/mnt/storage/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh077"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh077.XXXXXX)
clean_fortad_repo=

cleanup() {
    if test -n "$clean_fortad_repo"; then
        rm -rf "$clean_fortad_repo"
    fi
    rm -rf "$out"
}
trap cleanup EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for source in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -f "$source_dir/$source"
done

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)
if test "$fortad_original_commit" != "$required_fortad_commit" || test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_checkout")/fortad-lh077-clean.XXXXXX")
    rmdir "$clean_fortad_repo"
    git clone --shared --quiet "$fortad_checkout" "$clean_fortad_repo"
    git -C "$clean_fortad_repo" checkout --detach --quiet "$required_fortad_commit"
    fortad_repo="$clean_fortad_repo"
    fortad_worktree="temporary clean clone pinned to required commit"
else
    fortad_repo="$fortad_checkout"
    fortad_worktree="supplied checkout clean and pinned"
fi
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
if test ! -x "$fortad_repo/build/fo/bin/fortad"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
fortad="$fortad_repo/build/fo/bin/fortad"
test -x "$fortad"
test -x "$tapenade_repo/bin/tapenade"

mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/exact" "$out/port" "$out/mod"

compile_fixed() {
    local source=$1 label=$2
    local status=0
    "$fc" "${fixed_flags[@]}" -J"$out/mod" -I"$source_dir" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
    printf '%s\n' "$status"
}

compile_free() {
    local source=$1 label=$2
    local status=0
    "$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
    printf '%s\n' "$status"
}

exact_status=$(compile_fixed "$source_dir/program.f" upstream_primal)
parser_status=$(compile_fixed "$source_dir/program_p.f" upstream_parser)
tangent_status=$(compile_fixed "$source_dir/program_d.f" upstream_tangent)
reverse_status=$(compile_fixed "$source_dir/program_b.f" upstream_reverse)
multidirectional_status=$(compile_fixed "$source_dir/program_dv.f" upstream_multidirectional)
test "$exact_status" -eq 0
test "$parser_status" -eq 0
test "$tangent_status" -eq 0
test "$reverse_status" -eq 0
test "$multidirectional_status" -ne 0
grep -Fq 'Cannot open included file' "$out/upstream_multidirectional.stderr"

set +e
(cd "$out/tapenade/parser" && "$tapenade_repo/bin/tapenade" -p -root testinit -O . -o lh077 "$source_dir/program.f") \
    >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
fresh_parser_generation_status=$?
(cd "$out/tapenade/forward" && "$tapenade_repo/bin/tapenade" -d -root testinit -O . -o lh077 "$source_dir/program.f") \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
fresh_tangent_generation_status=$?
(cd "$out/tapenade/reverse" && "$tapenade_repo/bin/tapenade" -b -root testinit -O . -o lh077 "$source_dir/program.f") \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
fresh_reverse_generation_status=$?
set -e
for generated in "$out/tapenade/parser/lh077_p.f" "$out/tapenade/forward/lh077_d.f" "$out/tapenade/reverse/lh077_b.f"; do
    test -s "$generated"
done
test "$fresh_parser_generation_status" -eq 0
test "$fresh_tangent_generation_status" -eq 0
test "$fresh_reverse_generation_status" -eq 0
fresh_parser_status=$(compile_fixed "$out/tapenade/parser/lh077_p.f" fresh_parser)
fresh_tangent_status=$(compile_fixed "$out/tapenade/forward/lh077_d.f" fresh_tangent)
fresh_reverse_status=$(compile_fixed "$out/tapenade/reverse/lh077_b.f" fresh_reverse)
test "$fresh_parser_status" -eq 0
test "$fresh_tangent_status" -eq 0
test "$fresh_reverse_status" -eq 0

set +e
"$fortad" --mode forward --indep A,B,C --proc testInit --name lh077_exact_forward \
    --module lh077_exact_forward_mod --output "$out/exact/forward.f90" "$source_dir/program.f" \
    >"$out/exact/forward.stdout" 2>"$out/exact/forward.stderr"
exact_fortad_forward_status=$?
"$fortad" --mode reverse --indep A,B,C --dep C --proc testInit --name lh077_exact_reverse \
    --module lh077_exact_reverse_mod --output "$out/exact/reverse.f90" "$source_dir/program.f" \
    >"$out/exact/reverse.stdout" 2>"$out/exact/reverse.stderr"
exact_fortad_reverse_status=$?
set -e
test "$exact_fortad_forward_status" -ne 0
test "$exact_fortad_reverse_status" -ne 0
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
grep -Fq 'fortad: inlining toto needs plain variables as arguments, because it may write to them' "$out/exact/forward.stderr"
grep -Fq 'fortad: inlining toto needs plain variables as arguments, because it may write to them' "$out/exact/reverse.stderr"

"$fortad" --mode forward --indep a,b,c --proc set01_lh077 --name lh077_forward \
    --module lh077_forward_mod --output "$out/port/forward.f90" "$case_dir/port.f90" \
    >"$out/port/forward.stdout" 2>"$out/port/forward.stderr"
"$fortad" --mode reverse --indep a,b,c --dep c_out --proc set01_lh077 --name lh077_reverse \
    --module lh077_reverse_mod --output "$out/port/reverse.f90" "$case_dir/port.f90" \
    >"$out/port/reverse.stdout" 2>"$out/port/reverse.stderr"
test -s "$out/port/forward.f90"
test -s "$out/port/reverse.f90"

bounded_port_status=$(compile_free "$case_dir/port.f90" bounded_port)
bounded_hand_status=$(compile_free "$case_dir/hand.f90" bounded_hand)
bounded_forward_compile_status=$(compile_free "$out/port/forward.f90" bounded_forward)
bounded_reverse_compile_status=$(compile_free "$out/port/reverse.f90" bounded_reverse)
test "$bounded_port_status" -eq 0
test "$bounded_hand_status" -eq 0
test "$bounded_forward_compile_status" -eq 0
test "$bounded_reverse_compile_status" -eq 0

harness_compile_status=$(compile_free "$case_dir/harness.f90" harness)
test "$harness_compile_status" -eq 0
"$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" \
    "$out/bounded_port.o" "$out/bounded_hand.o" "$out/bounded_forward.o" \
    "$out/bounded_reverse.o" "$out/harness.o" \
    >"$out/link.stdout" 2>"$out/link.stderr"
"$out/harness" >"$out/harness.stdout"
grep -Fq 'harness_status: pass' "$out/harness.stdout"
oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

exact_forward_diagnostic=$(grep -F 'fortad:' "$out/exact/forward.stderr" | head -1)
exact_reverse_diagnostic=$(grep -F 'fortad:' "$out/exact/reverse.stderr" | head -1)
multidirectional_diagnostic=$(grep -F 'Fatal Error:' "$out/upstream_multidirectional.stderr" | head -1)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh077\n'
    printf 'classification: expected-refusal-with-bounded-explicit-interface-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${fixed_flags[*]}"
    printf 'strict_free_flags: %s\n' "${free_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: testinit(A,B,C); toto(T,S,R)\n'
    printf 'bounded_entry_point: set01_lh077(a,b,c,c_out); independent: a,b,c; dependent: c_out\n'
    printf 'upstream_exact_strict_compile: primal=%s parser=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$exact_status" "$parser_status" "$tangent_status" "$reverse_status" "$multidirectional_status"
    printf 'upstream_multidirectional_diagnostic: %s\n' "$multidirectional_diagnostic"
    printf 'tapenade_options: parser=-p/-root testinit forward=-d/-root testinit reverse=-b/-root testinit\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser_generation_status" "$fresh_tangent_generation_status" "$fresh_reverse_generation_status"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser_status" "$fresh_tangent_status" "$fresh_reverse_status"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="%s"\n' \
        "$exact_fortad_forward_status" "$exact_forward_diagnostic"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="%s"\n' \
        "$exact_fortad_reverse_status" "$exact_reverse_diagnostic"
    printf 'fortad_bounded_forward: transform=pass status=0 compile=%s runtime=pass\n' "$bounded_forward_compile_status"
    printf 'fortad_bounded_reverse: transform=pass status=0 compile=%s runtime=pass\n' "$bounded_reverse_compile_status"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    cat "$out/harness.stdout"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh077_p.f lh077_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh077_d.f lh077_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh077_b.f lh077_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh077/manifest.toml \
        cases/tapenade-set01/lh077/notes.md cases/tapenade-set01/lh077/port.f90 \
        cases/tapenade-set01/lh077/hand.f90 cases/tapenade-set01/lh077/oracle.py \
        cases/tapenade-set01/lh077/harness.f90 cases/tapenade-set01/lh077/run.sh \
        cases/tapenade-set01/lh077/test_contract.py)
} >"$result"
cat "$result"
