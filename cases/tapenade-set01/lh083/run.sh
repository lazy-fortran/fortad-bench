#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=7adc75030db3fa4422339d82d2725ae29ee13dac
required_fortad_baseline_commit=3a946d34d3caa7a75fb6f891139023650b4ce51a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}

fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
source_dir="$tapenade_repo/nonRegressions/set01/lh083"
tap="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-lh083.XXXXXX)
trap 'rm -rf "$out"' EXIT

strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_baseline_commit" HEAD
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tap"
for source in program.f program_b.f; do test -s "$source_dir/$source"; done

mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/mod" "$out/fortad"

compile_status() {
    local label=$1 source=$2
    set +e
    "$fc" "${strict_flags[@]}" -fsyntax-only -I"$source_dir" \
        -J"$out/mod" "$source" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_free_status() {
    local label=$1 source=$2
    set +e
    "$fc" -std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
        -Wall -Wextra -Wimplicit-interface -fsyntax-only "$source" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_status exact_primal "$source_dir/program.f"
compile_status stored_reverse "$source_dir/program_b.f"
test "$(cat "$out/exact_primal.status")" -eq 0
test "$(cat "$out/stored_reverse.status")" -eq 0

set +e
(cd "$out/tapenade/parser" && "$tap" -p -O . -o lh083 "$source_dir/program.f") \
    >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
parser_status=$?
(cd "$out/tapenade/forward" && "$tap" -d -root aa -O . -o lh083 "$source_dir/program.f") \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
forward_status=$?
(cd "$out/tapenade/reverse" && "$tap" -b -root aa -O . -o lh083 "$source_dir/program.f") \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
reverse_status=$?
set -e
printf '%s\n' "$parser_status" >"$out/tapenade-parser.status"
printf '%s\n' "$forward_status" >"$out/tapenade-forward.status"
printf '%s\n' "$reverse_status" >"$out/tapenade-reverse.status"
test "$parser_status" -eq 0
test "$forward_status" -eq 0
test "$reverse_status" -eq 0

for generated in "$out/tapenade/parser/lh083_p.f" \
    "$out/tapenade/forward/lh083_d.f" "$out/tapenade/reverse/lh083_b.f"; do
    test -s "$generated"
    label="generated-$(basename "$generated")"
    compile_status "$label" "$generated"
    test "$(cat "$out/$label.status")" -eq 0
done

(cd "$fortad_repo" && fo build) >"$out/fortad-build.stdout" 2>"$out/fortad-build.stderr"
fortad="$fortad_repo/build/fo/bin/fortad"
test -x "$fortad"

run_fortad() {
    local label=$1
    shift
    set +e
    "$fortad" "$@" >"$out/fortad/$label.stdout" 2>"$out/fortad/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/fortad/$label.status"
}

run_fortad check check --proc aa --output "$out/fortad/check.txt" "$source_dir/program.f"
run_fortad jvp jvp X,Y --proc aa --name lh083_jvp --module lh083_jvp \
    --output "$out/fortad/jvp.f90" "$source_dir/program.f"
run_fortad vjp vjp X,Y --dep X --proc aa --name lh083_vjp --module lh083_vjp \
    --output "$out/fortad/vjp.f90" "$source_dir/program.f"
test "$(cat "$out/fortad/check.status")" -eq 0
test "$(cat "$out/fortad/jvp.status")" -eq 0
test "$(cat "$out/fortad/vjp.status")" -eq 1
test -s "$out/fortad/check.txt"
test -s "$out/fortad/jvp.f90"
test ! -e "$out/fortad/vjp.f90"
compile_free_status fortad_check_compile "$out/fortad/check.txt"
compile_free_status fortad_jvp_compile "$out/fortad/jvp.f90"
test "$(cat "$out/fortad_check_compile.status")" -eq 0
test "$(cat "$out/fortad_jvp_compile.status")" -eq 0
grep -Fqx "fortad: reverse mode: 'X' is both read and written in the same loop; that needs per-iteration storage" \
    "$out/fortad/vjp.stderr"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: tapenade nonRegressions/set01/lh083\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'classification: expected-refusal-exact-source-runtime-bounds-reverse-unavailable\n'
    printf 'upstream_exact_strict_compile: program.f=%s program_b.f=%s\n' \
        "$(cat "$out/exact_primal.status")" "$(cat "$out/stored_reverse.status")"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-forward.status")" "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_sources: parser=lh083_p.f forward=lh083_d.f reverse=lh083_b.f\n'
    printf 'tapenade_generated_strict_compile: parser=0 forward=0 reverse=0\n'
    printf 'fortad_exact_parser: generated-check-source-strict-compile\n'
    printf 'fortad_exact_forward: generated-jvp-source-strict-compile\n'
    printf 'fortad_exact_reverse: refusal-per-iteration-storage\n'
    printf 'independent_oracle: execution-prefix, first-out-of-bounds index, and LIFO restoration\n'
    printf '%s\n' "$oracle_output"
    printf 'port_result: forward-only-exact-source; no-complete-runtime reason=exact-fifth-write-is-X-157-and-vjp-needs-storage\n'
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        upstream/tapenade/nonRegressions/set01/lh083/program.f \
        upstream/tapenade/nonRegressions/set01/lh083/program_b.f)
} >"$result"
cat "$result"
