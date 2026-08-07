#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v101 allocation boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad/.git; then
    fortad_repo=/mnt/storage/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/todoF90/REFERENCES/v101"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in Options program.f90 program_Rb.f90 program_Rb.msg program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done

if test ! -x "$fortad"; then
    command -v fo >/dev/null
    (cd "$fortad_repo" && fo build) >/var/tmp/fortad-bench-v101-fortad-build.log 2>&1
fi
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >/var/tmp/fortad-bench-v101-tapenade-build.log 2>&1
fi
test -x "$fortad"
test -x "$tapenade"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-v101.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/upstream" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/exact/parser" "$out/exact/forward" \
    "$out/exact/reverse" "$out/port" "$out/port/mod"

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)

compile_free() {
    local label=$1
    local source=$2
    local moddir=$3
    local status
    mkdir -p "$moddir"
    if "$fc" "${strict_flags[@]}" -J"$moddir" -I"$source_dir" \
        -c "$source" -o "$out/$label.o" >"$out/$label.stdout" \
        2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_free upstream_primal "$source_dir/program.f90" "$out/upstream/primal-mod"
compile_free upstream_reverse "$source_dir/program_Rb.f90" "$out/upstream/reverse-mod"
compile_free upstream_forward "$source_dir/program_Rd.f90" "$out/upstream/forward-mod"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/upstream_reverse.status")" -eq 0
test "$(cat "$out/upstream_forward.status")" -eq 0

run_tapenade() {
    local mode=$1
    local flag=$2
    (cd "$out/fresh/$mode" && "$tapenade" -association byaddress \
        -vars x -outvars y "$flag" -O . -o v101 "$source_dir/program.f90") \
        >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr"
}

run_tapenade parser -p
run_tapenade forward -d
run_tapenade reverse -b
for generated in \
    "$out/fresh/parser/v101_p.f90" \
    "$out/fresh/forward/v101_d.f90" \
    "$out/fresh/reverse/v101_b.f90"; do
    test -s "$generated"
done
for message in \
    "$out/fresh/parser/v101_p.msg" \
    "$out/fresh/forward/v101_d.msg" \
    "$out/fresh/reverse/v101_b.msg"; do
    test -s "$message"
done

compile_free fresh_parser "$out/fresh/parser/v101_p.f90" "$out/fresh/parser-mod"
compile_free fresh_forward "$out/fresh/forward/v101_d.f90" "$out/fresh/forward-mod"
compile_free fresh_reverse "$out/fresh/reverse/v101_b.f90" "$out/fresh/reverse-mod"
test "$(cat "$out/fresh_parser.status")" -eq 0
test "$(cat "$out/fresh_forward.status")" -eq 0
test "$(cat "$out/fresh_reverse.status")" -eq 0

set +e
"$fortad" check --proc head -o "$out/exact/parser/head_checked.f90" \
    "$source_dir/program.f90" >"$out/fortad-exact-parser.stdout" \
    2>"$out/fortad-exact-parser.stderr"
exact_parser_status=$?
"$fortad" --mode forward --proc head --indep x --name head_d \
    --module v101_exact_forward --output "$out/exact/forward/head_d.f90" \
    "$source_dir/program.f90" >"$out/fortad-exact-forward.stdout" \
    2>"$out/fortad-exact-forward.stderr"
exact_forward_status=$?
"$fortad" --mode reverse --proc head --indep x --dep y --name head_b \
    --module v101_exact_reverse --output "$out/exact/reverse/head_b.f90" \
    "$source_dir/program.f90" >"$out/fortad-exact-reverse.stdout" \
    2>"$out/fortad-exact-reverse.stderr"
exact_reverse_status=$?
set -e
test "$exact_parser_status" -ne 0
test "$exact_forward_status" -ne 0
test "$exact_reverse_status" -ne 0
test ! -e "$out/exact/parser/head_checked.f90"
test ! -e "$out/exact/forward/head_d.f90"
test ! -e "$out/exact/reverse/head_b.f90"
for diagnostic in "$out/fortad-exact-parser.stderr" \
    "$out/fortad-exact-forward.stderr" "$out/fortad-exact-reverse.stderr"; do
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component' at line 6" "$diagnostic"
done

"$fortad" --mode forward --indep x --proc head_v101 \
    --name head_v101_forward --module v101_forward_mod \
    --output "$out/port/head_v101_forward.f90" "$case_dir/port.f90" \
    >"$out/fortad-bounded-forward.stdout" 2>"$out/fortad-bounded-forward.stderr"
"$fortad" --mode reverse --indep x --dep y --proc head_v101 \
    --name head_v101_reverse --module v101_reverse_mod \
    --output "$out/port/head_v101_reverse.f90" "$case_dir/port.f90" \
    >"$out/fortad-bounded-reverse.stdout" 2>"$out/fortad-bounded-reverse.stderr"
test -s "$out/port/head_v101_forward.f90"
test -s "$out/port/head_v101_reverse.f90"

compile_free bounded_port "$case_dir/port.f90" "$out/port/mod"
compile_free bounded_hand "$case_dir/hand.f90" "$out/port/mod"
compile_free bounded_forward "$out/port/head_v101_forward.f90" "$out/port/mod"
compile_free bounded_reverse "$out/port/head_v101_reverse.f90" "$out/port/mod"
test "$(cat "$out/bounded_port.status")" -eq 0
test "$(cat "$out/bounded_hand.status")" -eq 0
test "$(cat "$out/bounded_forward.status")" -eq 0
test "$(cat "$out/bounded_reverse.status")" -eq 0
"$fc" "${strict_flags[@]}" -J"$out/port/mod" \
    "$out/bounded_port.o" "$out/bounded_hand.o" "$out/bounded_forward.o" \
    "$out/bounded_reverse.o" "$case_dir/harness.f90" \
    -o "$out/harness" >"$out/harness-build.stdout" 2>"$out/harness-build.stderr"
"$out/harness" >"$out/harness.stdout" 2>"$out/harness.stderr"
grep -Fqx 'harness_status: pass' "$out/harness.stdout"

oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade todoF90 REFERENCES v101 allocated local array\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: clean-and-pinned\n'
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: head(x,y)\n'
    printf 'ported_entry_point: head_v101(x,y); independent: x; dependent: y\n'
    printf 'tapenade_options: -association byaddress -vars x -outvars y; parser=-p forward=-d reverse=-b\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_reverse=%s stored_forward=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/upstream_reverse.status")" \
        "$(cat "$out/upstream_forward.status")"
    printf 'stored_references: program_Rb.f90/.msg program_Rd.f90/.msg\n'
    printf 'tapenade_generation: parser=0 tangent=0 reverse=0\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" "$(cat "$out/fresh_forward.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocatable declaration/component at line 6"\n' "$exact_parser_status"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocatable declaration/component at line 6"\n' "$exact_forward_status"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="unsupported allocation lifetime construct allocatable declaration/component at line 6"\n' "$exact_reverse_status"
    printf 'fortad_bounded_forward: transform=0 compile=%s runtime=pass\n' "$(cat "$out/bounded_forward.status")"
    printf 'fortad_bounded_reverse: transform=0 compile=%s runtime=pass\n' "$(cat "$out/bounded_reverse.status")"
    printf 'bounded_port_scope: fixed-size a(2) normal allocated path only; allocation failure and unallocated state not claimed\n'
    printf 'bounded_port_compile: %s hand_compile: %s harness_compile: 0\n' \
        "$(cat "$out/bounded_port.status")" "$(cat "$out/bounded_hand.status")"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    printf '%s\n' "$(cat "$out/harness.stdout")"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum Options program.f90 program_Rb.f90 program_Rb.msg program_Rd.f90 program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v101_p.f90 v101_p.msg)
    (cd "$out/fresh/forward" && sha256sum v101_d.f90 v101_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v101_b.f90 v101_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v101/manifest.toml \
        cases/tapenade-set01/v101/notes.md cases/tapenade-set01/v101/port.f90 \
        cases/tapenade-set01/v101/hand.f90 cases/tapenade-set01/v101/oracle.py \
        cases/tapenade-set01/v101/harness.f90 cases/tapenade-set01/v101/run.sh \
        cases/tapenade-set01/v101/test_contract.py)
} >"$result"

cat "$result"
