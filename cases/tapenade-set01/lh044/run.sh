#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh044 invalid-upstream closure.
set -euo pipefail

root=$(cd "$(dirname "$0")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh044"
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fsyntax-only)

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -d "$fortad_checkout/.git" || test -f "$fortad_checkout/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

source_dir="$tapenade_repo/nonRegressions/set01/lh044"
include_source="$tapenade_repo/nonRegressions/DIFFSIZES.f"
source_harness="$case_dir/harness.f"
for source in program.f program_p.f program_d.f program_b.f program_dv.f \
              program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -s "$source_dir/$source"
done
test -s "$include_source"
test -s "$source_harness"

out=$(mktemp -d /var/tmp/tapenade-set01-lh044.XXXXXX)
clean_fortad_repo=
cleanup() {
    test -z "$clean_fortad_repo" || rm -rf "$clean_fortad_repo"
    rm -rf "$out"
}
trap cleanup EXIT
mkdir -p "$out/include" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/mod"
ln -s "$include_source" "$out/include/DIFFSIZES.inc"

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_checkout" status --porcelain)
if test "$fortad_original_commit" != "$required_fortad_commit" || \
   test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$root/../fortad-lh044-clean.XXXXXX")
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

compile_capture() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_flags[@]}" -I "$out/include" -J "$out/mod" "$source" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    compile_capture "$source_dir/$source" "upstream-${source%.f}"
    test "$(cat "$out/upstream-${source%.f}.status")" -ne 0
    grep -Fq "DUMMY attribute conflicts with INTRINSIC attribute" \
        "$out/upstream-${source%.f}.stderr"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

compile_capture "$source_harness" source-harness
test "$(cat "$out/source-harness.status")" -ne 0
grep -Fq "DUMMY attribute conflicts with INTRINSIC attribute" \
    "$out/source-harness.stderr"

if test ! -x "$tapenade_repo/bin/tapenade" || \
   test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"

tapenade_start=$(date +%s.%N)
"$tapenade" -p -root invert -O "$out/tapenade/parser" -o lh044 \
    "$source_dir/program.f" >"$out/tapenade-parser.stdout" \
    2>"$out/tapenade-parser.stderr"
"$tapenade" -d -root invert -O "$out/tapenade/forward" -o lh044 \
    "$source_dir/program.f" >"$out/tapenade-forward.stdout" \
    2>"$out/tapenade-forward.stderr"
"$tapenade" -b -root invert -O "$out/tapenade/reverse" -o lh044 \
    "$source_dir/program.f" >"$out/tapenade-reverse.stdout" \
    2>"$out/tapenade-reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

parser_source="$out/tapenade/parser/lh044_p.f"
forward_source="$out/tapenade/forward/lh044_d.f"
reverse_source="$out/tapenade/reverse/lh044_b.f"
for generated in "$parser_source" "$forward_source" "$reverse_source"; do
    test -s "$generated"
done
for spec in "parser $parser_source" "tangent $forward_source" "reverse $reverse_source"; do
    read -r label generated <<<"$spec"
    compile_capture "$generated" "fresh-$label"
    test "$(cat "$out/fresh-$label.status")" -ne 0
    grep -Fq "DUMMY attribute conflicts with INTRINSIC attribute" \
        "$out/fresh-$label.stderr"
done

fortad_bin="$fortad_repo/build/fo/bin/fortad"
(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
test -x "$fortad_bin"

fortad_probe() {
    local mode=$1 output=$2 log=$3
    set +e
    "$fortad_bin" --mode "$mode" --indep a0,b0 --dep invert --proc invert \
        --name "lh044_${mode}" --module "lh044_${mode}_mod" --output "$output" \
        "$source_dir/program.f" >"$log.stdout" 2>"$log.stderr"
    local status=$?
    set -e
    test "$status" -ne 0
    grep -Fq "fortad: unsupported statement at line 5" "$log.stderr"
    test ! -e "$output"
    printf '%s\n' "$status" >"$log.status"
}

fortad_start=$(date +%s.%N)
fortad_probe forward "$out/fortad-forward.f90" "$out/fortad-forward"
fortad_probe reverse "$out/fortad-reverse.f90" "$out/fortad-reverse"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh044\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_compiler_flags: %s -I %s\n' "${strict_flags[*]}" "$out/include"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
        printf 'upstream_%s_strict_compile: expected-refusal status=%s diagnostic=FX1-intrinsic-dummy\n' \
            "$source" "$(cat "$out/upstream-${source%.f}.status")"
    done
    printf 'stored_diagnostics: program_p.msg program_d.msg program_b.msg program_dv.msg retained\n'
    printf 'source_harness: expected-refusal diagnostic=FX1-intrinsic-dummy\n'
    printf 'tapenade_fresh_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile: parser=expected-refusal tangent=expected-refusal reverse=expected-refusal\n'
    printf 'tapenade_generated_diagnostic: DUMMY attribute conflicts with INTRINSIC attribute\n'
    printf 'fortad_transform_seconds: %s\n' "$fortad_seconds"
    printf 'fortad_forward: expected-refusal status=%s at line 5\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_reverse: expected-refusal status=%s at line 5\n' "$(cat "$out/fortad-reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: strict compiler rejection identity for exact and stored sources; no numerical semantics-preserving port\n'
    printf '%s\n' "$oracle_output"
    printf 'closure: no standard-conforming port or support claim; repairing FX1 or unresolved callbacks would invent upstream semantics\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$parser_source" "$out/tapenade/parser/lh044_p.msg" \
        "$forward_source" "$out/tapenade/forward/lh044_d.msg" \
        "$reverse_source" "$out/tapenade/reverse/lh044_b.msg"
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh044/manifest.toml \
        cases/tapenade-set01/lh044/notes.md cases/tapenade-set01/lh044/oracle.py \
        cases/tapenade-set01/lh044/harness.f cases/tapenade-set01/lh044/run.sh \
        cases/tapenade-set01/lh044/test_contract.py)
} >"$result"

cat "$result"
