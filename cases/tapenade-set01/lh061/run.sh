#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh061 callback-boundary evidence.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh061"
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=0e156041c1f92736c1e35f8164b37992c4c8d780
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
tapenade_commit=$(git -C "$tapenade_repo" rev-parse HEAD)
if test "$tapenade_commit" != "$required_tapenade_commit"; then
    printf 'Tapenade checkout must be pinned at %s\n' "$required_tapenade_commit" >&2
    exit 1
fi
if test -n "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"; then
    printf 'Tapenade checkout has tracked changes\n' >&2
    exit 1
fi
fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
if test "$fortad_commit" != "$required_fortad_commit"; then
    printf 'FortAD checkout must be pinned at %s\n' "$required_fortad_commit" >&2
    exit 1
fi
if test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"; then
    fortad_worktree=clean
else
    fortad_worktree=dirty-preserved-user-changes
fi

source_dir="$tapenade_repo/nonRegressions/set01/lh061"
for source in program.f program_p.f program_d.f program_b.f program_dv.f \
              program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh061.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/mod"

compile_capture() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_flags[@]}" -c "$source" -o "$out/$label.o" \
        >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_capture "$source_dir/program.f" upstream-primal
compile_capture "$source_dir/program_p.f" upstream-parser
compile_capture "$source_dir/program_d.f" upstream-tangent
compile_capture "$source_dir/program_b.f" upstream-reverse
compile_capture "$source_dir/program_dv.f" upstream-multidirectional
for label in upstream-primal upstream-parser upstream-tangent upstream-reverse; do
    test "$(cat "$out/$label.status")" = 0
done
test "$(cat "$out/upstream-multidirectional.status")" -ne 0
grep -Fq "Cannot open included file" "$out/upstream-multidirectional.log"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

if test ! -x "$tapenade_repo/bin/tapenade" || \
   test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

tapenade_start=$(date +%s.%N)
"$tapenade" -p -root test -O "$out/tapenade/parser" -o lh061 \
    "$source_dir/program.f" >"$out/tapenade/parser.stdout" \
    2>"$out/tapenade/parser.stderr"
"$tapenade" -d -root test -O "$out/tapenade/forward" -o lh061 \
    "$source_dir/program.f" >"$out/tapenade/forward.stdout" \
    2>"$out/tapenade/forward.stderr"
"$tapenade" -b -root test -O "$out/tapenade/reverse" -o lh061 \
    "$source_dir/program.f" >"$out/tapenade/reverse.stdout" \
    2>"$out/tapenade/reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

parser_source="$out/tapenade/parser/lh061_p.f"
forward_source="$out/tapenade/forward/lh061_d.f"
reverse_source="$out/tapenade/reverse/lh061_b.f"
for generated in "$parser_source" "$forward_source" "$reverse_source"; do
    test -s "$generated"
done
compile_capture "$parser_source" fresh-parser
compile_capture "$forward_source" fresh-tangent
compile_capture "$reverse_source" fresh-reverse
for label in fresh-parser fresh-tangent fresh-reverse; do
    test "$(cat "$out/$label.status")" = 0
done

fortad_bin=${FORTAD_BIN:-"$fortad_repo/build/fo/bin/fortad"}
if test ! -x "$fortad_bin"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
test -x "$fortad_bin"

fortad_probe() {
    local mode=$1 label=$2
    set +e
    "$fortad_bin" --mode "$mode" --indep y --dep y --proc test \
        --name "lh061_${mode}" --module "lh061_${mode}_mod" \
        --output "$out/$label.f90" "$source_dir/program.f" \
        >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

fortad_start=$(date +%s.%N)
fortad_probe forward fortad-exact-forward
fortad_probe reverse fortad-exact-reverse
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')
test "$(cat "$out/fortad-exact-forward.status")" -ne 0
test "$(cat "$out/fortad-exact-reverse.status")" -ne 0
grep -Fq "independent 'y' is not declared in test" \
    "$out/fortad-exact-forward.log"
grep -Fq "dependent 'y' is not declared in test" \
    "$out/fortad-exact-reverse.log"
test ! -e "$out/fortad-exact-forward.f90"
test ! -e "$out/fortad-exact-reverse.f90"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh061\n'
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
    printf 'upstream_exact_source_strict_compile: pass\n'
    printf 'upstream_stored_parser_strict_compile: pass\n'
    printf 'upstream_stored_tangent_strict_compile: pass\n'
    printf 'upstream_stored_reverse_strict_compile: pass\n'
    printf 'upstream_stored_multidirectional_strict_compile: expected-refusal missing-DIFFSIZES.inc\n'
    printf 'tapenade_fresh_generation_seconds_total: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile: parser=pass tangent=pass reverse=pass\n'
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic=implicit-y-not-declared\n' \
        "$(cat "$out/fortad-exact-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic=implicit-y-not-declared\n' \
        "$(cat "$out/fortad-exact-reverse.status")"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'no_bounded_numerical_port: unresolved-callback-semantics\n'
    printf 'independent_oracle: strict compiler acceptance/refusal identity; no numerical oracle because F, JAC, PJAC, and SLVS are not supplied by the corpus row\n'
    printf '%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'tapenade_generated_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh061_p.f lh061_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh061_d.f lh061_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh061_b.f lh061_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh061/manifest.toml \
        cases/tapenade-set01/lh061/notes.md cases/tapenade-set01/lh061/oracle.py \
        cases/tapenade-set01/lh061/run.sh cases/tapenade-set01/lh061/test_contract.py)
} >"$result"

cat "$result"
