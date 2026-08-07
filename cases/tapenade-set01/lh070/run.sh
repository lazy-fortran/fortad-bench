#!/usr/bin/env bash
# Validate pinned Tapenade set01/lh070 with exact, fresh, and bounded evidence.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_checkout/.git" && test -e /home/ert/code/lazy-fortran/fortad/.git; then
    fortad_checkout=/home/ert/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=0e156041c1f92736c1e35f8164b37992c4c8d780
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh070"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh070.XXXXXX)
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
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_checkout")/fortad-lh070-clean.XXXXXX")
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
    set +e
    "$fc" "${fixed_flags[@]}" -J"$out/mod" -I"$source_dir" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    printf '%s\n' "$status"
}

compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
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

(cd "$out/tapenade/parser" && "$tapenade_repo/bin/tapenade" -p -root top -O . -o lh070 "$source_dir/program.f") \
    >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade_repo/bin/tapenade" -d -root top -O . -o lh070 "$source_dir/program.f") \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade_repo/bin/tapenade" -b -root top -O . -o lh070 "$source_dir/program.f") \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
for generated in "$out/tapenade/parser/lh070_p.f" "$out/tapenade/forward/lh070_d.f" "$out/tapenade/reverse/lh070_b.f"; do
    test -s "$generated"
done
fresh_parser_status=$(compile_fixed "$out/tapenade/parser/lh070_p.f" fresh_parser)
fresh_tangent_status=$(compile_fixed "$out/tapenade/forward/lh070_d.f" fresh_tangent)
fresh_reverse_status=$(compile_fixed "$out/tapenade/reverse/lh070_b.f" fresh_reverse)
test "$fresh_parser_status" -eq 0
test "$fresh_tangent_status" -eq 0
test "$fresh_reverse_status" -eq 0

set +e
"$fortad" --mode forward --indep A,B --proc top --name lh070_exact_forward \
    --module lh070_exact_forward_mod --output "$out/exact/forward.f90" "$source_dir/program.f" \
    >"$out/exact/forward.stdout" 2>"$out/exact/forward.stderr"
exact_fortad_forward_status=$?
"$fortad" --mode reverse --indep A,B --dep A --proc top --name lh070_exact_reverse \
    --module lh070_exact_reverse_mod --output "$out/exact/reverse.f90" "$source_dir/program.f" \
    >"$out/exact/reverse.stdout" 2>"$out/exact/reverse.stderr"
exact_fortad_reverse_status=$?
set -e
test "$exact_fortad_forward_status" -ne 0
test "$exact_fortad_reverse_status" -ne 0
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
grep -Fq 'fortad: unsupported statement at line 4' "$out/exact/forward.stderr"
grep -Fq 'fortad: unsupported statement at line 4' "$out/exact/reverse.stderr"

"$fortad" --mode forward --indep a,b,x,z --proc set01_lh070 --name lh070_forward \
    --module lh070_forward_mod --output "$out/port/forward.f90" "$case_dir/port.f90" \
    >"$out/port/forward.stdout" 2>"$out/port/forward.stderr"
"$fortad" --mode reverse --indep a,b,x,z --dep y --proc set01_lh070 --name lh070_reverse_y \
    --module lh070_reverse_y_mod --output "$out/port/reverse_y.f90" "$case_dir/port.f90" \
    >"$out/port/reverse_y.stdout" 2>"$out/port/reverse_y.stderr"
test -s "$out/port/forward.f90"
test -s "$out/port/reverse_y.f90"
bounded_forward_transform_status=0
bounded_reverse_transform_status=0
port_status=$(compile_free "$case_dir/port.f90" bounded_port)
hand_status=$(compile_free "$case_dir/hand.f90" bounded_hand)
bounded_forward_compile_status=$(compile_free "$out/port/forward.f90" bounded_forward)
bounded_reverse_compile_status=$(compile_free "$out/port/reverse_y.f90" bounded_reverse_y)
test "$port_status" -eq 0
test "$hand_status" -eq 0
test "$bounded_forward_compile_status" -eq 0
test "$bounded_reverse_compile_status" -eq 0

compile_free "$case_dir/harness.f90" harness >/dev/null
"$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" \
    "$out/bounded_port.o" "$out/bounded_hand.o" "$out/bounded_forward.o" \
    "$out/bounded_reverse_y.o" "$out/harness.o" \
    >"$out/link.stdout" 2>"$out/link.stderr"
"$out/harness" >"$out/harness.stdout"
grep -Fq 'harness_status: pass' "$out/harness.stdout"
oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh070\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
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
    printf 'upstream_exact_strict_compile: primal=%s parser=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$exact_status" "$parser_status" "$tangent_status" "$reverse_status" "$multidirectional_status"
    printf 'upstream_multidirectional_diagnostic: missing-DIFFSIZES.inc\n'
    printf 'tapenade_options: parser=-p/-root top forward=-d/-root top reverse=-b/-root top\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser_status" "$fresh_tangent_status" "$fresh_reverse_status"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="unsupported statement at line 4 COMMON /cc/"\n' "$exact_fortad_forward_status"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="unsupported statement at line 4 COMMON /cc/"\n' "$exact_fortad_reverse_status"
    printf 'fortad_bounded_forward: transform=pass status=%s compile=%s runtime=pass\n' "$bounded_forward_transform_status" "$bounded_forward_compile_status"
    printf 'fortad_bounded_reverse_y: transform=pass status=%s compile=%s runtime=pass\n' "$bounded_reverse_transform_status" "$bounded_reverse_compile_status"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    cat "$out/harness.stdout"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh070_p.f lh070_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh070_d.f lh070_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh070_b.f lh070_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh070/manifest.toml \
        cases/tapenade-set01/lh070/notes.md cases/tapenade-set01/lh070/port.f90 \
        cases/tapenade-set01/lh070/hand.f90 cases/tapenade-set01/lh070/oracle.py \
        cases/tapenade-set01/lh070/harness.f90 cases/tapenade-set01/lh070/run.sh \
        cases/tapenade-set01/lh070/test_contract.py)
} >"$result"
cat "$result"
