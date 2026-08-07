#!/usr/bin/env bash
# Validate pinned Tapenade todoF90/REFERENCES/v02 with exact and bounded evidence.
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
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/todoF90/REFERENCES/v02"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-v02.XXXXXX)
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
for source in program.f90 program_b.f90; do
    test -s "$source_dir/$source"
done
test -f "$source_dir/program_b.msg"

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)
if test "$fortad_original_commit" != "$required_fortad_commit" || test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_checkout")/fortad-v02-clean.XXXXXX")
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

mkdir -p "$out/upstream/mod" "$out/fresh/parser/mod" "$out/fresh/forward/mod" \
    "$out/fresh/reverse/mod" "$out/exact/parser/mod" "$out/exact/forward/mod" \
    "$out/bounded/mod"

compile_free() {
    local source=$1 label=$2 moddir=$3
    local status=0
    "$fc" "${free_flags[@]}" -J"$moddir" -I"$source_dir" -I"$moddir" \
        -c "$source" -o "$out/$label.o" >"$out/$label.stdout" \
        2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status"
}

upstream_primal_status=$(compile_free "$source_dir/program.f90" upstream_primal "$out/upstream/mod")
stored_reverse_status=$(compile_free "$source_dir/program_b.f90" stored_reverse "$out/upstream/mod")
test "$upstream_primal_status" -eq 0
test "$stored_reverse_status" -eq 0

set +e
"$fortad" check --proc top -o "$out/exact/parser/program_checked.f90" \
    "$source_dir/program.f90" >"$out/exact-parser.stdout" 2>"$out/exact-parser.stderr"
exact_parser_transform_status=$?
"$fortad" --mode forward --proc top --indep i1,i3 --name top_d \
    --module v02_exact_forward --output "$out/exact/forward/top_d.f90" \
    "$source_dir/program.f90" >"$out/exact-forward.stdout" 2>"$out/exact-forward.stderr"
exact_forward_transform_status=$?
"$fortad" --mode reverse --proc top --indep i1,i3 --dep o1 --name top_b \
    --module v02_exact_reverse --output "$out/exact/reverse/top_b.f90" \
    "$source_dir/program.f90" >"$out/exact-reverse.stdout" 2>"$out/exact-reverse.stderr"
exact_reverse_transform_status=$?
set -e
test -s "$out/exact/parser/program_checked.f90"
test -s "$out/exact/forward/top_d.f90"
test ! -e "$out/exact/reverse/top_b.f90"
exact_parser_compile_status=$(compile_free "$out/exact/parser/program_checked.f90" exact_parser_compile "$out/exact/parser/mod")
exact_forward_compile_status=$(compile_free "$out/exact/forward/top_d.f90" exact_forward_compile "$out/exact/forward/mod")
test "$exact_parser_transform_status" -eq 0
test "$exact_parser_compile_status" -ne 0
test "$exact_forward_transform_status" -eq 0
test "$exact_forward_compile_status" -ne 0
test "$exact_reverse_transform_status" -ne 0
grep -Fq "fortad: assignment to undeclared 'g'" "$out/exact-reverse.stderr"

for mode in parser forward reverse; do
    case "$mode" in
        parser) flags=(-p -root top);;
        forward) flags=(-d -root top);;
        reverse) flags=(-b -root top);;
    esac
    set +e
    (cd "$out/fresh/$mode" && "$tapenade_repo/bin/tapenade" -nooptim spareinit \
        "${flags[@]}" -O . -o v02 "$source_dir/program.f90") \
        >"$out/fresh-$mode.stdout" 2>"$out/fresh-$mode.stderr"
    eval "fresh_${mode}_generation_status=\$?"
    set -e
    test -s "$out/fresh/$mode/v02_${mode/p/parser}.f90" 2>/dev/null || true
done
test -s "$out/fresh/parser/v02_p.f90"
test -s "$out/fresh/forward/v02_d.f90"
test -s "$out/fresh/reverse/v02_b.f90"
fresh_parser_status=$(compile_free "$out/fresh/parser/v02_p.f90" fresh_parser "$out/fresh/parser/mod")
fresh_forward_status=$(compile_free "$out/fresh/forward/v02_d.f90" fresh_forward "$out/fresh/forward/mod")
fresh_reverse_status=$(compile_free "$out/fresh/reverse/v02_b.f90" fresh_reverse "$out/fresh/reverse/mod")
test "$fresh_parser_generation_status" -eq 0
test "$fresh_forward_generation_status" -eq 0
test "$fresh_reverse_generation_status" -eq 0
test "$fresh_parser_status" -eq 0
test "$fresh_forward_status" -eq 0
test "$fresh_reverse_status" -ne 0

"$fortad" --mode forward --proc top_v02 --indep i2_in,i3 \
    --name top_v02_forward --module v02_forward_mod \
    --output "$out/bounded/top_v02_forward.f90" "$case_dir/port.f90" \
    >"$out/bounded-forward.stdout" 2>"$out/bounded-forward.stderr"
bounded_forward_transform_status=$?
"$fortad" --mode reverse --proc top_v02 --indep i2_in,i3 --dep o1 \
    --name top_v02_reverse_o1 --module v02_reverse_mod \
    --output "$out/bounded/top_v02_reverse_o1.f90" "$case_dir/port.f90" \
    >"$out/bounded-reverse.stdout" 2>"$out/bounded-reverse.stderr"
bounded_reverse_transform_status=$?
test "$bounded_forward_transform_status" -eq 0
test "$bounded_reverse_transform_status" -eq 0
test -s "$out/bounded/top_v02_forward.f90"
test -s "$out/bounded/top_v02_reverse_o1.f90"

bounded_port_status=$(compile_free "$case_dir/port.f90" bounded_port "$out/bounded/mod")
bounded_hand_status=$(compile_free "$case_dir/hand.f90" bounded_hand "$out/bounded/mod")
bounded_forward_status=$(compile_free "$out/bounded/top_v02_forward.f90" bounded_forward "$out/bounded/mod")
bounded_reverse_status=$(compile_free "$out/bounded/top_v02_reverse_o1.f90" bounded_reverse "$out/bounded/mod")
test "$bounded_port_status" -eq 0
test "$bounded_hand_status" -eq 0
test "$bounded_forward_status" -eq 0
test "$bounded_reverse_status" -eq 0

"$fc" "${free_flags[@]}" -J"$out/bounded/mod" -I"$out/bounded/mod" \
    -c "$case_dir/harness.f90" -o "$out/bounded/harness.o" \
    >"$out/bounded-harness.stdout" 2>"$out/bounded-harness.stderr"
"$fc" "${free_flags[@]}" -J"$out/bounded/mod" -I"$out/bounded/mod" \
    -o "$out/bounded/harness" "$out/bounded_port.o" \
    "$out/bounded_hand.o" "$out/bounded_forward.o" "$out/bounded_reverse.o" \
    "$out/bounded/harness.o" >"$out/bounded-link.stdout" 2>"$out/bounded-link.stderr"
"$out/bounded/harness" >"$out/bounded-harness.run"
grep -Fq 'harness_status: pass' "$out/bounded-harness.run"
oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

exact_parser_diagnostic=$(grep -F 'Error:' "$out/exact_parser_compile.stderr" | head -1)
exact_forward_diagnostic=$(grep -F 'Error:' "$out/exact_forward_compile.stderr" | head -1)
exact_reverse_diagnostic=$(grep -F 'fortad:' "$out/exact-reverse.stderr" | head -1)
fresh_reverse_diagnostic=$(grep -F 'Error:' "$out/fresh_reverse.stderr" | head -1)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES v02\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_free_flags: %s\n' "${free_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: modu.top(i1,i3,o1,o2,o3)\n'
    printf 'bounded_entry_point: top_v02(i2_in,i3,o1,o2,o3); independent: i2_in,i3; dependent: o1\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_reverse=%s\n' \
        "$upstream_primal_status" "$stored_reverse_status"
    printf 'tapenade_options: -nooptim spareinit; parser=-p/-root top forward=-d/-root top reverse=-b/-root top\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser_generation_status" "$fresh_forward_generation_status" "$fresh_reverse_generation_status"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser_status" "$fresh_forward_status" "$fresh_reverse_status"
    printf 'tapenade_fresh_reverse_diagnostic: %s\n' "$fresh_reverse_diagnostic"
    printf 'fortad_exact_parser: transform=%s strict_compile=%s diagnostic="%s"\n' \
        "$exact_parser_transform_status" "$exact_parser_compile_status" "$exact_parser_diagnostic"
    printf 'fortad_exact_forward: transform=%s strict_compile=%s diagnostic="%s"\n' \
        "$exact_forward_transform_status" "$exact_forward_compile_status" "$exact_forward_diagnostic"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="%s"\n' \
        "$exact_reverse_transform_status" "$exact_reverse_diagnostic"
    printf 'fortad_bounded_forward: transform=%s compile=%s runtime=pass\n' \
        "$bounded_forward_transform_status" "$bounded_forward_status"
    printf 'fortad_bounded_reverse: transform=%s compile=%s runtime=pass\n' \
        "$bounded_reverse_transform_status" "$bounded_reverse_status"
    printf 'bounded_port_compile: %s hand_compile: %s harness_compile: 0\n' \
        "$bounded_port_status" "$bounded_hand_status"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    cat "$out/bounded-harness.run"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f90 program_b.f90 program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v02_p.f90 v02_p.msg)
    (cd "$out/fresh/forward" && sha256sum v02_d.f90 v02_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v02_b.f90 v02_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v02/manifest.toml \
        cases/tapenade-set01/v02/notes.md cases/tapenade-set01/v02/port.f90 \
        cases/tapenade-set01/v02/hand.f90 cases/tapenade-set01/v02/oracle.py \
        cases/tapenade-set01/v02/harness.f90 cases/tapenade-set01/v02/run.sh \
        cases/tapenade-set01/v02/test_contract.py)
} >"$result"
cat "$result"
