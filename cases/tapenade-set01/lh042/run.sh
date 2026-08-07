#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh042 invalid-upstream boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh042"
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

source_dir="$tapenade_repo/nonRegressions/set01/lh042"
for source in program.f program_d.f program_b.f program_dv.f program_p.f; do
    test -s "$source_dir/$source"
done
for reference in Options program_d.msg program_b.msg program_dv.msg program_p.msg; do
    test -s "$source_dir/$reference"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh042.XXXXXX)
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/tapenade/vector" "$out/mod"

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

for source in program.f program_d.f program_b.f program_dv.f program_p.f; do
    compile_capture "$source_dir/$source" "upstream-$source"
    test "$(cat "$out/upstream-$source.status")" -ne 0
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

if test ! -x "$tapenade_repo/bin/tapenade" || test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"

tapenade_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -o lh042_p "$source_dir/program.f") >"$out/tapenade-parser.log" 2>&1
(cd "$out/tapenade/forward" && "$tapenade" -d -root decls1 -o lh042_d "$source_dir/program.f") >"$out/tapenade-forward.log" 2>&1
(cd "$out/tapenade/reverse" && "$tapenade" -b -root decls1 -o lh042_b "$source_dir/program.f") >"$out/tapenade-reverse.log" 2>&1
(cd "$out/tapenade/vector" && "$tapenade" -d -root decls1 -multi -o lh042_dv "$source_dir/program.f") >"$out/tapenade-vector.log" 2>&1
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" 'BEGIN {printf "%.6f", b-a}')

parser_source="$out/tapenade/parser/lh042_p_p.f"
forward_source="$out/tapenade/forward/lh042_d_d.f"
reverse_source="$out/tapenade/reverse/lh042_b_b.f"
vector_source="$out/tapenade/vector/lh042_dv_dv.f"
for generated in "$parser_source" "$forward_source" "$reverse_source" "$vector_source"; do
    test -s "$generated"
done
compile_capture "$parser_source" generated-parser
compile_capture "$forward_source" generated-forward
compile_capture "$reverse_source" generated-reverse
compile_capture "$vector_source" generated-vector
for generated in parser forward reverse vector; do
    test "$(cat "$out/generated-$generated.status")" -ne 0
done

fortad_bin="$fortad_repo/build/fo/bin/fortad"
if test ! -x "$fortad_bin"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
test -x "$fortad_bin"

fortad_probe() {
    local mode=$1
    local output=$2
    local log=$3
    set +e
    "$fortad_bin" --mode "$mode" --indep t1 --dep t1 --proc decls1 \
        --name "lh042_${mode}" --module "lh042_${mode}_mod" \
        --output "$output" "$source_dir/program.f" >"$log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/fortad-$mode.status"
    test "$status" -ne 0
    grep -Fq "fortad: parse failed:" "$log"
    test ! -e "$output"
}

fortad_start=$(date +%s.%N)
fortad_probe forward "$out/lh042_forward.f90" "$out/fortad-forward.log"
fortad_probe reverse "$out/lh042_reverse.f90" "$out/fortad-reverse.log"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" 'BEGIN {printf "%.6f", b-a}')

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh042\n'
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
    printf 'entry_point: decls1(t1,t2,t3,n,m,t4,t5)\n'
    printf 'tapenade_options: parser=-p forward=-d/-root decls1 reverse=-b/-root decls1 multidirectional=-d/-root decls1/-multi\n'
    printf 'upstream_exact_source_strict_compile: expected-refusal\n'
    for source in program.f program_d.f program_b.f program_dv.f program_p.f; do
        printf 'upstream_%s_strict_compile: expected-refusal status=%s\n' "$source" "$(cat "$out/upstream-$source.status")"
    done
    printf 'stored_references: Options program_d.f/.msg program_b.f/.msg program_dv.f/.msg program_p.f/.msg\n'
    printf 'tapenade_generation_seconds_total: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass forward=pass reverse=pass multidirectional=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=expected-refusal forward=expected-refusal reverse=expected-refusal multidirectional=expected-refusal\n'
    for generated in parser forward reverse vector; do
        printf 'tapenade_%s_strict_compile: expected-refusal status=%s\n' "$generated" "$(cat "$out/generated-$generated.status")"
    done
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'fortad_forward: expected-refusal parse declaration-order line 10 status=%s\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_reverse: expected-refusal parse declaration-order line 10 status=%s\n' "$(cat "$out/fortad-reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-parse-refusal\n'
    printf 'independent_oracle: strict compiler diagnostic identity; no numerical oracle because the upstream source is invalid\n'
    printf '%s\n' "$oracle_output"
    printf 'closure: no standard-conforming port or support claim; repairing declarations or the absent include would invent upstream semantics\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum Options program.f program_d.f program_d.msg program_b.f program_b.msg program_dv.f program_dv.msg program_p.f program_p.msg)
    printf 'tapenade_generated_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh042_p_p.f lh042_p_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh042_d_d.f lh042_d_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh042_b_b.f lh042_b_b.msg)
    (cd "$out/tapenade/vector" && sha256sum lh042_dv_dv.f lh042_dv_dv.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh042/manifest.toml cases/tapenade-set01/lh042/notes.md cases/tapenade-set01/lh042/oracle.py cases/tapenade-set01/lh042/run.sh cases/tapenade-set01/lh042/test_contract.py)
} >"$result"

cat "$result"
