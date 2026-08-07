#!/usr/bin/env bash
# Validate pinned Tapenade set01/lh072 with exact, fresh, and bounded evidence.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade}
fc=${FC:-gfortran}

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fixed_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh072"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh072.XXXXXX)
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
command -v fo >/dev/null
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
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_checkout")/fortad-lh072-clean.XXXXXX")
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
    "$out/tapenade/reverse" "$out/exact" "$out/bounded" "$out/mod"

compile_fixed() {
    local source=$1 label=$2
    set +e
    "$fc" "${fixed_flags[@]}" -J"$out/mod" -I"$source_dir" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    printf '%s' "$status"
}

compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    printf '%s' "$status"
}

upstream_primal_status=$(compile_fixed "$source_dir/program.f" upstream_primal)
upstream_parser_status=$(compile_fixed "$source_dir/program_p.f" upstream_parser)
upstream_tangent_status=$(compile_fixed "$source_dir/program_d.f" upstream_tangent)
upstream_reverse_status=$(compile_fixed "$source_dir/program_b.f" upstream_reverse)
upstream_multidirectional_status=$(compile_fixed "$source_dir/program_dv.f" upstream_multidirectional)
test "$upstream_primal_status" -eq 0
test "$upstream_parser_status" -eq 0
test "$upstream_tangent_status" -eq 0
test "$upstream_reverse_status" -eq 0
test "$upstream_multidirectional_status" -ne 0
grep -Fq 'Cannot open included file' "$out/upstream_multidirectional.stderr"

(cd "$out/tapenade/parser" && "$tapenade_repo/bin/tapenade" -p -root top -O . \
    -o lh072 "$source_dir/program.f") >"$out/tapenade-parser.stdout" \
    2>"$out/tapenade-parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade_repo/bin/tapenade" -d -root top -O . \
    -o lh072 "$source_dir/program.f") >"$out/tapenade-forward.stdout" \
    2>"$out/tapenade-forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade_repo/bin/tapenade" -b -root top -O . \
    -o lh072 "$source_dir/program.f") >"$out/tapenade-reverse.stdout" \
    2>"$out/tapenade-reverse.stderr"
test -s "$out/tapenade/parser/lh072_p.f"
test -s "$out/tapenade/forward/lh072_d.f"
test -s "$out/tapenade/reverse/lh072_b.f"
fresh_parser_status=$(compile_fixed "$out/tapenade/parser/lh072_p.f" fresh_parser)
fresh_tangent_status=$(compile_fixed "$out/tapenade/forward/lh072_d.f" fresh_tangent)
fresh_reverse_status=$(compile_fixed "$out/tapenade/reverse/lh072_b.f" fresh_reverse)
test "$fresh_parser_status" -eq 0
test "$fresh_tangent_status" -eq 0
test "$fresh_reverse_status" -eq 0

set +e
"$fortad" --mode forward --indep A,B --proc top --name lh072_exact_forward \
    --module lh072_exact_forward_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f" >"$out/exact/forward.stdout" \
    2>"$out/exact/forward.stderr"
exact_fortad_forward_status=$?
"$fortad" --mode reverse --indep A,B --dep A --proc top --name lh072_exact_reverse \
    --module lh072_exact_reverse_mod --output "$out/exact/reverse.f90" \
    "$source_dir/program.f" >"$out/exact/reverse.stdout" \
    2>"$out/exact/reverse.stderr"
exact_fortad_reverse_status=$?
set -e
test "$exact_fortad_forward_status" -ne 0
test "$exact_fortad_reverse_status" -ne 0
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
grep -Fq 'fortad: inlining toto would need a statement form it does not have' \
    "$out/exact/forward.stderr"
grep -Fq 'fortad: inlining toto would need a statement form it does not have' \
    "$out/exact/reverse.stderr"

"$fortad" --mode forward --indep a_in,b_in --proc set01_lh072 \
    --name lh072_forward --module lh072_forward_mod \
    --output "$out/bounded/forward.f90" "$case_dir/port.f90" \
    >"$out/bounded/forward.stdout" 2>"$out/bounded/forward.stderr"
bounded_forward_transform_status=$?
"$fortad" --mode reverse --indep a_in,b_in --dep a_sum --proc set01_lh072 \
    --name lh072_reverse_a_sum --module lh072_reverse_a_sum_mod \
    --output "$out/bounded/reverse_a_sum.f90" "$case_dir/port.f90" \
    >"$out/bounded/reverse_a_sum.stdout" \
    2>"$out/bounded/reverse_a_sum.stderr"
bounded_reverse_transform_status=$?
test -s "$out/bounded/forward.f90"
test -s "$out/bounded/reverse_a_sum.f90"
port_status=$(compile_free "$case_dir/port.f90" bounded_port)
hand_status=$(compile_free "$case_dir/hand.f90" bounded_hand)
bounded_forward_compile_status=$(compile_free "$out/bounded/forward.f90" bounded_forward)
bounded_reverse_compile_status=$(compile_free "$out/bounded/reverse_a_sum.f90" bounded_reverse_a_sum)
test "$bounded_forward_transform_status" -eq 0
test "$bounded_reverse_transform_status" -eq 0
test "$port_status" -eq 0
test "$hand_status" -eq 0
test "$bounded_forward_compile_status" -eq 0
test "$bounded_reverse_compile_status" -eq 0

compile_free "$case_dir/harness.f90" harness >/dev/null
test "$(cat "$out/harness.status")" -eq 0
"$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" \
    "$out/bounded_port.o" "$out/bounded_hand.o" \
    "$out/bounded_forward.o" "$out/bounded_reverse_a_sum.o" \
    "$out/harness.o" >"$out/link.stdout" 2>"$out/link.stderr"
"$out/harness" >"$out/harness.stdout"
grep -Fq 'harness_status: pass' "$out/harness.stdout"
oracle_output=$(python3 "$case_dir/oracle.py")
printf '%s\n' "$oracle_output" >"$out/oracle.txt"
grep -Fq 'oracle_status: pass' "$out/oracle.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh072\n'
    printf 'classification: expected-refusal-with-bounded-callback-specialization\n'
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
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_exact_strict_compile: primal=%s parser=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$upstream_primal_status" "$upstream_parser_status" "$upstream_tangent_status" \
        "$upstream_reverse_status" "$upstream_multidirectional_status"
    printf 'upstream_multidirectional_diagnostic: missing-DIFFSIZES.inc\n'
    printf 'tapenade_options: parser=-p/-root top forward=-d/-root top reverse=-b/-root top\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser_status" "$fresh_tangent_status" "$fresh_reverse_status"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="inlining toto would need a statement form it does not have"\n' \
        "$exact_fortad_forward_status"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="inlining toto would need a statement form it does not have"\n' \
        "$exact_fortad_reverse_status"
    printf 'fortad_bounded_forward: transform=%s compile=%s\n' \
        "$bounded_forward_transform_status" "$bounded_forward_compile_status"
    printf 'fortad_bounded_reverse_a_sum: transform=%s compile=%s\n' \
        "$bounded_reverse_transform_status" "$bounded_reverse_compile_status"
    printf 'bounded_port_compile: port=%s hand=%s harness=%s\n' \
        "$port_status" "$hand_status" "$(cat "$out/harness.status")"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, callback check, and adjoint identity\n'
    cat "$out/oracle.txt"
    cat "$out/harness.stdout"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/tapenade/parser/lh072_p.f" "$out/tapenade/forward/lh072_d.f" \
        "$out/tapenade/reverse/lh072_b.f"
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh072/manifest.toml \
        cases/tapenade-set01/lh072/notes.md cases/tapenade-set01/lh072/port.f90 \
        cases/tapenade-set01/lh072/hand.f90 cases/tapenade-set01/lh072/harness.f90 \
        cases/tapenade-set01/lh072/oracle.py cases/tapenade-set01/lh072/run.sh \
        cases/tapenade-set01/lh072/test_contract.py)
} >"$result"
cat "$result"
