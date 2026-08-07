#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh056"
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=0e156041c1f92736c1e35f8164b37992c4c8d780
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x "$fortad_repo/build/fo/bin/fortad"
test -x "$tapenade_repo/bin/tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

source_dir="$tapenade_repo/nonRegressions/set01/lh056"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for message in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -s "$source_dir/$message"
done

out=$(mktemp -d /var/tmp/fortad-set01-lh056.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/parser" "$out/forward" "$out/reverse" "$out/mod"

fixed_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only -pedantic-errors \
    -Wall -Wextra -Wimplicit-interface -cpp -I"$source_dir" -J"$out/mod")

compile_fixed() {
    local label=$1
    local source=$2
    set +e
    "$fc" "${fixed_flags[@]}" "$source" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    compile_fixed "upstream_${source%.f}" "$source_dir/$source"
done
test "$(cat "$out/upstream_program.status")" -ne 0
test "$(cat "$out/upstream_program_p.status")" -ne 0
test "$(cat "$out/upstream_program_d.status")" -eq 0
test "$(cat "$out/upstream_program_b.status")" -eq 0
test "$(cat "$out/upstream_program_dv.status")" -ne 0
grep -Fq 'Different type kinds' "$out/upstream_program.log"
grep -Fq 'not compatible with an intrinsic' "$out/upstream_program.log"
grep -Fq 'Different type kinds' "$out/upstream_program_p.log"
grep -Fq 'not compatible with an intrinsic' "$out/upstream_program_p.log"
grep -Fq 'Cannot open included file' "$out/upstream_program_dv.log"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

tapenade="$tapenade_repo/bin/tapenade"
(cd "$out/parser" && "$tapenade" -p -o lh056_p "$source_dir/program.f") >"$out/parser.log" 2>&1
(cd "$out/forward" && "$tapenade" -d -root f -o lh056_d "$source_dir/program.f") >"$out/forward.log" 2>&1
(cd "$out/reverse" && "$tapenade" -b -root f -o lh056_b "$source_dir/program.f") >"$out/reverse.log" 2>&1
for generated in "$out/parser/lh056_p_p.f" "$out/forward/lh056_d_d.f" "$out/reverse/lh056_b_b.f"; do
    test -s "$generated"
done

compile_fixed fresh_parser "$out/parser/lh056_p_p.f"
compile_fixed fresh_forward "$out/forward/lh056_d_d.f"
compile_fixed fresh_reverse "$out/reverse/lh056_b_b.f"
test "$(cat "$out/fresh_parser.status")" -ne 0
test "$(cat "$out/fresh_forward.status")" -eq 0
test "$(cat "$out/fresh_reverse.status")" -eq 0
grep -Fq 'Different type kinds' "$out/fresh_parser.log"
grep -Fq 'not compatible with an intrinsic' "$out/fresh_parser.log"

fortad="$fortad_repo/build/fo/bin/fortad"
fortad_probe() {
    local mode=$1
    local output="$out/fortad_${mode}.f90"
    set +e
    "$fortad" --mode "$mode" --indep t --dep f --proc f \
        --name "lh056_${mode}" --module "lh056_${mode}_mod" --output "$output" \
        "$source_dir/program.f" >"$out/fortad_${mode}.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/fortad_${mode}.status"
    test "$status" -ne 0
    grep -Fq 'fortad: unsupported statement at line 3' "$out/fortad_${mode}.log"
    test ! -e "$output"
}

fortad_probe forward
fortad_probe reverse

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh056\n'
    printf 'classification: unsupported-invalid-upstream-fortran\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${fixed_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'entry_point: f(t)\n'
    printf 'tapenade_options: parser=-p forward=-d/-root f reverse=-b/-root f\n'
    printf 'upstream_program.f_strict_compile: expected-refusal status=%s diagnostic=mixed-kind-three-argument-AMIN1\n' "$(cat "$out/upstream_program.status")"
    printf 'upstream_program_p.f_strict_compile: expected-refusal status=%s diagnostic=mixed-kind-three-argument-AMIN1\n' "$(cat "$out/upstream_program_p.status")"
    printf 'upstream_program_d.f_strict_compile: pass status=%s stored-tangent-syntax-only\n' "$(cat "$out/upstream_program_d.status")"
    printf 'upstream_program_b.f_strict_compile: pass status=%s stored-reverse-syntax-only\n' "$(cat "$out/upstream_program_b.status")"
    printf 'upstream_program_dv.f_strict_compile: expected-refusal status=%s diagnostic=missing-DIFFSIZES.inc\n' "$(cat "$out/upstream_program_dv.status")"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_parser_strict_compile: expected-refusal status=%s diagnostic=mixed-kind-three-argument-AMIN1\n' "$(cat "$out/fresh_parser.status")"
    printf 'tapenade_forward_strict_compile: pass status=%s syntax-only-external-AMIN1_D\n' "$(cat "$out/fresh_forward.status")"
    printf 'tapenade_reverse_strict_compile: pass status=%s syntax-only-external-AMIN1_B-stack\n' "$(cat "$out/fresh_reverse.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic=unsupported-INTRINSIC-AMIN1\n' "$(cat "$out/fortad_forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic=unsupported-INTRINSIC-AMIN1\n' "$(cat "$out/fortad_reverse.status")"
    printf 'fortad_bounded_port: not-applicable-invalid-upstream-no-semantics-preserving-repair\n'
    printf 'independent_oracle: strict compiler diagnostic identity; no numerical derivative oracle because the upstream call is invalid\n'
    printf '%s\n' "$oracle_output"
    printf 'closure: no bounded port or exact-support claim; repairing AMIN1 argument count or kinds would invent upstream semantics\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'tapenade_generated_sha256:\n'
    (cd "$out/parser" && sha256sum lh056_p_p.f lh056_p_p.msg)
    (cd "$out/forward" && sha256sum lh056_d_d.f lh056_d_d.msg)
    (cd "$out/reverse" && sha256sum lh056_b_b.f lh056_b_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh056/manifest.toml cases/tapenade-set01/lh056/notes.md cases/tapenade-set01/lh056/oracle.py cases/tapenade-set01/lh056/run.sh cases/tapenade-set01/lh056/test_contract.py)
} >"$result"

cat "$result"
