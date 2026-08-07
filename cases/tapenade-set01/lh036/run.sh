#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh036 invalid-upstream boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh036"
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
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

source_dir="$tapenade_repo/nonRegressions/set01/lh036"
for source in program.f program_d.f program_p.f program_d.msg program_p.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh036.XXXXXX)
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/mod"

strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp -I"$source_dir" -J"$out/mod")

compile_capture() {
    local source=$1
    local label=$2
    set +e
    "$fc" "${strict_flags[@]}" "$source" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

for source in program.f program_d.f program_p.f; do
    compile_capture "$source_dir/$source" "upstream-$source"
    test "$(cat "$out/upstream-$source.status")" -ne 0
    grep -Fq "The function result on the lhs of the assignment" "$out/upstream-$source.log"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

if test ! -x "$tapenade_repo/bin/tapenade" || test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"

tapenade_start=$(date +%s.%N)
"$tapenade" -p -O "$out/tapenade/parser" -o lh036 "$source_dir/program.f" >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
"$tapenade" -d -root f -O "$out/tapenade/forward" -o lh036 "$source_dir/program.f" >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
"$tapenade" -b -root f -O "$out/tapenade/reverse" -o lh036 "$source_dir/program.f" >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" 'BEGIN {printf "%.6f", b-a}')

parser_source="$out/tapenade/parser/lh036_p.f"
forward_source="$out/tapenade/forward/lh036_d.f"
reverse_source="$out/tapenade/reverse/lh036_b.f"
for generated in "$parser_source" "$forward_source" "$reverse_source"; do
    test -s "$generated"
done
compile_capture "$parser_source" generated-parser
compile_capture "$forward_source" generated-forward
compile_capture "$reverse_source" generated-reverse
test "$(cat "$out/generated-parser.status")" -ne 0
grep -Fq "The function result on the lhs of the assignment" "$out/generated-parser.log"
test "$(cat "$out/generated-forward.status")" -ne 0
grep -Fq "The function result on the lhs of the assignment" "$out/generated-forward.log"
test "$(cat "$out/generated-reverse.status")" -eq 0

fortad_bin="$fortad_repo/build/fo/bin/fortad"
if test ! -x "$fortad_bin"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
test -x "$fortad_bin"

fortad_probe() {
    local mode=$1
    local output=$2
    local log=$3
    local status
    set +e
    if test "$mode" = forward; then
        "$fortad_bin" --mode forward --indep t --proc f --name lh036_jvp --module lh036_jvp_mod --output "$output" "$source_dir/program.f" >"$log" 2>&1
    else
        "$fortad_bin" --mode reverse --indep t --dep f --proc f --name lh036_vjp --module lh036_vjp_mod --output "$output" "$source_dir/program.f" >"$log" 2>&1
    fi
    status=$?
    set -e
    test "$status" -ne 0
    grep -Fq "fortad: unsupported statement at line 9" "$log"
    test ! -e "$output"
}

fortad_start=$(date +%s.%N)
fortad_probe forward "$out/lh036_forward.f90" "$out/fortad-forward.log"
fortad_probe reverse "$out/lh036_reverse.f90" "$out/fortad-reverse.log"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" 'BEGIN {printf "%.6f", b-a}')

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh036\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_program.f_strict_compile: expected-refusal status=%s\n' "$(cat "$out/upstream-program.f.status")"
    printf 'upstream_program_d.f_strict_compile: expected-refusal status=%s\n' "$(cat "$out/upstream-program_d.f.status")"
    printf 'upstream_program_p.f_strict_compile: expected-refusal status=%s\n' "$(cat "$out/upstream-program_p.f.status")"
    printf 'upstream_stored_diagnostics: program_d.msg and program_p.msg retained\n'
    printf 'tapenade_generation_seconds_total: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass forward=pass reverse=pass\n'
    printf 'tapenade_parser_strict_compile: expected-refusal status=%s\n' "$(cat "$out/generated-parser.status")"
    printf 'tapenade_forward_strict_compile: expected-refusal status=%s\n' "$(cat "$out/generated-forward.status")"
    printf 'tapenade_reverse_strict_compile: pass\n'
    printf 'fortad_build_check: pass\n'
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'fortad_forward: expected-refusal at line 9\n'
    printf 'fortad_reverse: expected-refusal at line 9\n'
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: strict compiler rejection identity; no numerical oracle because ZE/TRUC/TRUC1 semantics are absent\n'
    printf '%s\n' "$oracle_output"
    printf 'closure: no standard-conforming port or support claim; repairing declarations would invent upstream semantics\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_d.f program_p.f program_d.msg program_p.msg)
    printf 'tapenade_generated_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh036_p.f lh036_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh036_d.f lh036_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh036_b.f lh036_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh036/manifest.toml cases/tapenade-set01/lh036/notes.md cases/tapenade-set01/lh036/oracle.py cases/tapenade-set01/lh036/run.sh cases/tapenade-set01/lh036/test_contract.py)
} >"$result"

cat "$result"
