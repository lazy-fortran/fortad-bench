#!/usr/bin/env bash
# Reproducible strict, fresh-generation, oracle, and exact FortAD probe.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=7adc75030db3fa4422339d82d2725ae29ee13dac
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/lh081
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh081.XXXXXX)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"

for source in program.f program_p.f program_d.f program_b.f program_dv.f \
    program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -s "$source_dir/$source"
done

mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only
    -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_fixed() {
    local label=$1
    local source=$2
    run_status "compile-$label" "$fc" "${strict_fixed[@]}" "$source" -o "$out/$label.o"
}

for source in program program_p program_d program_b; do
    compile_fixed "exact-$source" "$source_dir/$source.f"
    test "$(cat "$out/compile-exact-$source.status")" -eq 0
done
compile_fixed exact-program_dv "$source_dir/program_dv.f"
test "$(cat "$out/compile-exact-program_dv.status")" -ne 0
grep -Fq "Cannot open included file" "$out/compile-exact-program_dv.stderr"

tapenade_start=$(date +%s.%N)
run_status tapenade-parser "$tapenade" -p -O "$out/fresh/parser" -o lh081 \
    "$source_dir/program.f"
run_status tapenade-forward "$tapenade" -d -root test2 -O "$out/fresh/forward" -o lh081 \
    "$source_dir/program.f"
run_status tapenade-reverse "$tapenade" -b -root test2 -O "$out/fresh/reverse" -o lh081 \
    "$source_dir/program.f"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" 'BEGIN {printf "%.6f", b-a}')
for mode in parser forward reverse; do
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
done
fresh_parser="$out/fresh/parser/lh081_p.f"
fresh_forward="$out/fresh/forward/lh081_d.f"
fresh_reverse="$out/fresh/reverse/lh081_b.f"
for generated in "$fresh_parser" "$fresh_forward" "$fresh_reverse"; do
    test -s "$generated"
    generated_stem=$(basename "$generated" .f)
    compile_fixed "fresh-$generated_stem" "$generated"
    test "$(cat "$out/compile-fresh-$generated_stem.status")" -eq 0
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" \
    --forward "$fresh_forward" --reverse "$fresh_reverse")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

fortad_start=$(date +%s.%N)
run_status fortad-forward "$fortad" --mode forward --indep a --proc test2 \
    --name lh081_forward --module lh081_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --indep a --dep a --proc test2 \
    --name lh081_reverse --module lh081_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" 'BEGIN {printf "%.6f", b-a}')
test "$(cat "$out/fortad-forward.status")" -ne 0
test "$(cat "$out/fortad-reverse.status")" -ne 0
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
for mode in forward reverse; do
    grep -Fq "inlining test would need a statement form it does not have" \
        "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
done

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set01 lh081\n'
    printf 'classification: unsupported-external-procedure-inlining\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: test2(a,f,jac,pjac)\n'
    printf 'selected_entry_points: test2\n'
    printf 'tapenade_options: parser=-p forward=-d/-root test2 reverse=-b/-root test2\n'
    printf 'upstream_exact_strict_compile: primal=0 parser=0 tangent=0 reverse=0 multidirectional=expected-refusal-missing-DIFFSIZES.inc\n'
    printf 'tapenade_generation: parser=0 forward=0 reverse=0 elapsed_seconds=%s\n' "$tapenade_seconds"
    printf 'tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=0\n'
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic=external-call-inlining\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic=external-call-inlining\n' "$(cat "$out/fortad-reverse.status")"
    printf 'fortad_transform_elapsed_seconds: %s\n' "$fortad_seconds"
    printf 'independent_oracle: source-call-graph tangent-propagation adjoint-propagation\n'
    printf '%s\n' "$oracle_output"
    printf 'port_result: not-applicable-no-invented-external-routines-or-root\n'
    printf 'runner_result: pass\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_p.f \
        "$source_rel"/program_d.f "$source_rel"/program_b.f "$source_rel"/program_dv.f \
        "$source_rel"/program_p.msg "$source_rel"/program_d.msg \
        "$source_rel"/program_b.msg "$source_rel"/program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum lh081_p.f lh081_p.msg)
    (cd "$out/fresh/forward" && sha256sum lh081_d.f lh081_d.msg)
    (cd "$out/fresh/reverse" && sha256sum lh081_b.f lh081_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
