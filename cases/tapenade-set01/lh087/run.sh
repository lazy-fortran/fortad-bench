#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh087 exact-source boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh087"
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=7adc75030db3fa4422339d82d2725ae29ee13dac
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
tapenade_commit=$(git -C "$tapenade_repo" rev-parse HEAD)
test "$tapenade_commit" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
test "$fortad_commit" = "$required_fortad_commit"
if test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"; then
    fortad_worktree=clean
else
    fortad_worktree=dirty-preserved-user-changes
fi

source_dir="$tapenade_repo/nonRegressions/set01/lh087"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for message in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -f "$source_dir/$message"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh087.XXXXXX)
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse"

compile_capture() {
    local source=$1 label=$2 extra=${3:-}
    set +e
    # shellcheck disable=SC2086
    "$fc" "${strict_flags[@]}" $extra -c "$source" -o "$out/$label.o" \
        >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

for source in program.f program_p.f program_d.f program_b.f; do
    compile_capture "$source_dir/$source" "upstream-${source%.f}"
    test "$(cat "$out/upstream-${source%.f}.status")" = 0
done
compile_capture "$source_dir/program_dv.f" upstream-multidirectional
test "$(cat "$out/upstream-multidirectional.status")" -ne 0
grep -Fqi "Cannot open included file" "$out/upstream-multidirectional.log"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"
tapenade_start=$(date +%s.%N)
for mode in p d b; do
    case "$mode" in
        p) target=parser ;;
        d) target=forward ;;
        b) target=reverse ;;
    esac
    "$tapenade" -"$mode" -root nl_model_mie -O "$out/tapenade/$target" -o lh087 \
        "$source_dir/program.f" >"$out/tapenade/$target.stdout" \
        2>"$out/tapenade/$target.stderr"
done
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" 'BEGIN {printf "%.6f", b-a}')
parser_source="$out/tapenade/parser/lh087_p.f"
forward_source="$out/tapenade/forward/lh087_d.f"
reverse_source="$out/tapenade/reverse/lh087_b.f"
for generated in "$parser_source" "$forward_source" "$reverse_source"; do
    test -s "$generated"
    compile_capture "$generated" "fresh-$(basename "$generated" .f)"
    test "$(cat "$out/fresh-$(basename "$generated" .f).status")" = 0
done

fortad_bin=${FORTAD_BIN:-"$fortad_repo/build/fo/bin/fortad"}
test -x "$fortad_bin"
fortad_start=$(date +%s.%N)
set +e
"$fortad_bin" --mode forward --indep phase --indep number --indep sigma --dep pp \
    --proc nl_model_mie --name lh087_forward --module lh087_forward_mod \
    --output "$out/fortad-forward.f90" "$source_dir/program.f" \
    >"$out/fortad-forward.log" 2>&1
fortad_forward_status=$?
"$fortad_bin" --mode reverse --indep phase --indep number --indep sigma --dep pp \
    --proc nl_model_mie --name lh087_reverse --module lh087_reverse_mod \
    --output "$out/fortad-reverse.f90" "$source_dir/program.f" \
    >"$out/fortad-reverse.log" 2>&1
fortad_reverse_status=$?
set -e
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" 'BEGIN {printf "%.6f", b-a}')
test "$fortad_forward_status" = 0
test -s "$out/fortad-forward.f90"
compile_capture "$out/fortad-forward.f90" fortad-forward-standard -ffree-form
test "$(cat "$out/fortad-forward-standard.status")" = 0
compile_capture "$out/fortad-forward.f90" fortad-forward-warning-gate "-ffree-form -Werror=uninitialized"
test "$(cat "$out/fortad-forward-warning-gate.status")" -ne 0
grep -Fqi "uninitialized" "$out/fortad-forward-warning-gate.log"
test "$fortad_reverse_status" -ne 0
grep -Fq "dependent 'pp' is not declared in NL_MODEL_MIE" "$out/fortad-reverse.log"
test ! -e "$out/fortad-reverse.f90"

oracle_forward=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc" \
    --fortad-forward "$out/fortad-forward.f90")
grep -Fqx "oracle_status: pass" <<<"$oracle_forward"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh087\n'
    printf 'classification: expected-refusal-fortad-forward-unsafe-reverse-unavailable\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_source_strict_compile: pass\n'
    printf 'upstream_stored_parser_strict_compile: pass\n'
    printf 'upstream_stored_forward_strict_compile: pass\n'
    printf 'upstream_stored_reverse_strict_compile: pass\n'
    printf 'upstream_stored_multidirectional_strict_compile: expected-refusal missing-DIFFSIZES.inc\n'
    printf 'tapenade_fresh_generation_seconds_total: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile: parser=pass tangent=pass reverse=pass\n'
    printf 'fortad_transform_seconds_total: %s\n' "$fortad_seconds"
    printf 'fortad_exact_forward: emitted status=%s standard-compile=pass independent-warning-gate=expected-refusal-uninitialized-indices\n' "$fortad_forward_status"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic=dependent-pp-not-declared\n' "$fortad_reverse_status"
    printf 'fortad_generated_compile: standard=pass warning-gate=expected-refusal\n'
    printf 'no_bounded_numerical_port: exact-array-index-domain-is-undefined\n'
    printf 'independent_oracle: strict compiler plus source index-domain and generated-forward uninitialized-index checks\n'
    printf '%s\n' "$oracle_forward"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'tapenade_generated_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh087_p.f lh087_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh087_d.f lh087_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh087_b.f lh087_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh087/manifest.toml \
        cases/tapenade-set01/lh087/notes.md cases/tapenade-set01/lh087/oracle.py \
        cases/tapenade-set01/lh087/run.sh cases/tapenade-set01/lh087/test_contract.py)
} >"$result"

cat "$result"
