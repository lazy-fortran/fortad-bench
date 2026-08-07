#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh021 exact-source boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh021"
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
if test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"; then
    fortad_worktree=clean
else
    fortad_worktree=dirty-preserved-user-changes
fi

source_dir="$tapenade_repo/nonRegressions/set01/lh021"
for source in program.f program_d.f program_b.f program_d.msg program_b.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/ert/tapenade-set01-lh021.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse"

compile_capture() {
    local source=$1
    local object=$2
    local log=$3
    set +e
    "$fc" "${strict_flags[@]}" -c "$source" -o "$object" >"$log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status"
}

upstream_primal_status=$(compile_capture \
    "$source_dir/program.f" "$out/upstream-primal.o" "$out/upstream-primal.log")
upstream_tangent_status=$(compile_capture \
    "$source_dir/program_d.f" "$out/upstream-tangent.o" "$out/upstream-tangent.log")
upstream_reverse_status=$(compile_capture \
    "$source_dir/program_b.f" "$out/upstream-reverse.o" "$out/upstream-reverse.log")
test "$upstream_primal_status" = 0
test "$upstream_tangent_status" = 0
test "$upstream_reverse_status" -ne 0
grep -Fq "INTEGER*4" "$out/upstream-reverse.log"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

if test ! -x "$tapenade_repo/bin/tapenade" || \
   test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"

tapenade_start=$(date +%s.%N)
"$tapenade" -p -O "$out/tapenade/parser" -o lh021 "$source_dir/program.f" \
    >"$out/tapenade/parser.stdout" 2>"$out/tapenade/parser.stderr"
"$tapenade" -d -root s1 -O "$out/tapenade/forward" -o lh021 "$source_dir/program.f" \
    >"$out/tapenade/forward.stdout" 2>"$out/tapenade/forward.stderr"
"$tapenade" -b -root s1 -O "$out/tapenade/reverse" -o lh021 "$source_dir/program.f" \
    >"$out/tapenade/reverse.stdout" 2>"$out/tapenade/reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

parser_source="$out/tapenade/parser/lh021_p.f"
forward_source="$out/tapenade/forward/lh021_d.f"
reverse_source="$out/tapenade/reverse/lh021_b.f"
for generated in "$parser_source" "$forward_source" "$reverse_source"; do
    test -s "$generated"
done
parser_status=$(compile_capture "$parser_source" "$out/parser.o" "$out/parser.log")
forward_status=$(compile_capture "$forward_source" "$out/forward.o" "$out/forward.log")
reverse_status=$(compile_capture "$reverse_source" "$out/reverse.o" "$out/reverse.log")
test "$parser_status" = 0
test "$forward_status" = 0
test "$reverse_status" -ne 0
grep -Fq "INTEGER*4" "$out/reverse.log"

fortad_probe() {
    local mode=$1
    local output=$2
    local log=$3
    local status
    set +e
    if test "$mode" = forward; then
        (cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
            --indep x,y --proc s1 --name lh021_jvp --module lh021_jvp_mod \
            --output "$output" "$source_dir/program.f") >"$log" 2>&1
    else
        (cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
            --indep x,y --dep z --proc s1 --name lh021_vjp --module lh021_vjp_mod \
            --output "$output" "$source_dir/program.f") >"$log" 2>&1
    fi
    status=$?
    set -e
    test "$status" -ne 0
    grep -Fq "fortad: unsupported statement at line 5" "$log"
    test ! -e "$output"
}

fortad_start=$(date +%s.%N)
fortad_probe forward "$out/lh021_forward.f90" "$out/fortad-forward.log"
fortad_probe reverse "$out/lh021_reverse.f90" "$out/fortad-reverse.log"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh021\n'
    printf 'classification: expected-refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_source_compile: pass\n'
    printf 'upstream_stored_tangent_strict_compile: pass\n'
    printf 'upstream_stored_reverse_strict_compile: expected-refusal INTEGER*4\n'
    printf 'tapenade_fresh_generation_seconds_total: %s\n' "$tapenade_seconds"
    printf 'tapenade_parser_generation: pass\n'
    printf 'tapenade_forward_generation: pass\n'
    printf 'tapenade_reverse_generation: pass\n'
    printf 'tapenade_parser_strict_compile: pass\n'
    printf 'tapenade_forward_strict_compile: pass\n'
    printf 'tapenade_reverse_strict_compile: expected-refusal INTEGER*4\n'
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'fortad_forward: expected-refusal at line 5 (COMMON /c1/)\n'
    printf 'fortad_reverse: expected-refusal at line 5 (COMMON /c1/)\n'
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'fortad_build_check: not-run-case-uses-fo-exec-no-build\n'
    printf 'independent_oracle: strict compiler acceptance/refusal identity; no numerical oracle because S2 and S3 are not supplied by the corpus row\n'
    printf 'oracle_exact_primal: pass\n'
    printf 'oracle_stored_tangent: pass\n'
    printf 'oracle_stored_reverse: expected-refusal INTEGER*4\n'
    printf 'oracle_status: pass\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_d.f program_b.f program_d.msg program_b.msg)
    printf 'tapenade_generated_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh021_p.f)
    (cd "$out/tapenade/forward" && sha256sum lh021_d.f)
    (cd "$out/tapenade/reverse" && sha256sum lh021_b.f)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh021/manifest.toml \
        cases/tapenade-set01/lh021/notes.md cases/tapenade-set01/lh021/oracle.py \
        cases/tapenade-set01/lh021/run.sh cases/tapenade-set01/lh021/test_contract.py)
} >"$result"
cat "$result"
