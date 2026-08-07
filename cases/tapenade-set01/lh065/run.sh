#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh065 invalid-upstream boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh065"
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

source_dir="$tapenade_repo/nonRegressions/set01/lh065"
for source in program.f program_p.f program_d.f program_p.msg program_d.msg; do
    test -s "$source_dir/$source"
done
test ! -e "$source_dir/program_b.f"
test ! -e "$source_dir/program_b.msg"
test ! -e "$source_dir/program_dv.f"

out=$(mktemp -d /var/tmp/tapenade-set01-lh065.XXXXXX)
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/mod"

strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp -I"$source_dir" -J"$out/mod")

compile_capture() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_flags[@]}" "$source" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

for source in program.f program_p.f program_d.f; do
    compile_capture "$source_dir/$source" "exact-$source"
    test "$(cat "$out/exact-$source.status")" -ne 0
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

if test ! -x "$tapenade_repo/bin/tapenade" || \
   test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

(cd "$out/tapenade/parser" && "$tapenade" -p -o lh065 "$source_dir/program.f") >"$out/tapenade-parser.log" 2>&1
(cd "$out/tapenade/forward" && "$tapenade" -d -root top -o lh065 "$source_dir/program.f") >"$out/tapenade-forward.log" 2>&1
(cd "$out/tapenade/reverse" && "$tapenade" -b -root top -o lh065 "$source_dir/program.f") >"$out/tapenade-reverse.log" 2>&1

parser_source="$out/tapenade/parser/lh065_p.f"
forward_source="$out/tapenade/forward/lh065_d.f"
reverse_source="$out/tapenade/reverse/lh065_b.f"
for generated in "$parser_source" "$forward_source" "$reverse_source"; do
    test -s "$generated"
done
compile_capture "$parser_source" fresh-parser
compile_capture "$forward_source" fresh-tangent
compile_capture "$reverse_source" fresh-reverse
for generated in parser tangent reverse; do
    test "$(cat "$out/fresh-$generated.status")" -ne 0
done

fortad_bin=${FORTAD_BIN:-"$fortad_repo/build/fo/bin/fortad"}
if test ! -x "$fortad_bin"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
test -x "$fortad_bin"

fortad_probe() {
    local mode=$1 output=$2 log=$3
    set +e
    "$fortad_bin" --mode "$mode" --indep in --dep out --proc top \
        --name "lh065_${mode}" --module "lh065_${mode}_mod" --output "$output" \
        "$source_dir/program.f" >"$log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/fortad-$mode.status"
    test "$status" -ne 0
    grep -Fq "fortad: unsupported statement at line 9" "$log"
    test ! -e "$output"
}

fortad_probe forward "$out/fortad-forward.f90" "$out/fortad-forward.log"
fortad_probe reverse "$out/fortad-reverse.f90" "$out/fortad-reverse.log"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh065\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'entry_point: top(in,out,N)\n'
    printf 'tapenade_options: parser=-p forward=-d/-root top reverse=-b/-root top\n'
    printf 'upstream_program.f_strict_compile: expected-refusal status=%s\n' "$(cat "$out/exact-program.f.status")"
    printf 'upstream_program_p.f_strict_compile: expected-refusal status=%s\n' "$(cat "$out/exact-program_p.f.status")"
    printf 'upstream_program_d.f_strict_compile: expected-refusal status=%s\n' "$(cat "$out/exact-program_d.f.status")"
    printf 'stored_references: program_p.f/.msg program_d.f/.msg\n'
    printf 'missing_stored_references: program_b.f/.msg program_dv.f\n'
    printf 'tapenade_generation: parser=pass forward=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=expected-refusal forward=expected-refusal reverse=expected-refusal\n'
    printf 'tapenade_parser_strict_compile: expected-refusal status=%s\n' "$(cat "$out/fresh-parser.status")"
    printf 'tapenade_forward_strict_compile: expected-refusal status=%s\n' "$(cat "$out/fresh-tangent.status")"
    printf 'tapenade_reverse_strict_compile: expected-refusal status=%s\n' "$(cat "$out/fresh-reverse.status")"
    printf 'fortad_forward: expected-refusal COMMON line 9 status=%s\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_reverse: expected-refusal COMMON line 9 status=%s\n' "$(cat "$out/fortad-reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-parse-refusal\n'
    printf 'independent_oracle: strict compiler diagnostic identity; no numerical oracle because the upstream source has invalid REAL/INTEGER aliasing and inconsistent COMMON storage\n'
    printf '%s\n' "$oracle_output"
    printf 'closure: no standard-conforming port or support claim; repairing casts, callback types, or COMMON layout would change the upstream semantics\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_p.msg program_d.f program_d.msg)
    printf 'tapenade_generated_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh065_p.f lh065_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh065_d.f lh065_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh065_b.f lh065_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh065/manifest.toml cases/tapenade-set01/lh065/notes.md cases/tapenade-set01/lh065/oracle.py cases/tapenade-set01/lh065/run.sh cases/tapenade-set01/lh065/test_contract.py)
} >"$result"

cat "$result"
