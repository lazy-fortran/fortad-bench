#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh030 and its bounded FortAD port.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh030"
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
strict_free=(-std=f2018 -pedantic-errors -ffree-line-length-none -O2 -fno-lto)
source_dir="$tapenade_repo/nonRegressions/set01/lh030"

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain)"
for source in program.f program_p.f program_d.f program_b.f program_dv.f \
              program_b.msg program_d.msg program_dv.msg program_p.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh030.XXXXXX)
clean_fortad_repo=
cleanup() {
    if test -n "$clean_fortad_repo"; then
        rm -rf "$clean_fortad_repo"
    fi
    rm -rf "$out"
}
trap cleanup EXIT

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_checkout" status --porcelain)
if test "$fortad_original_commit" != "$required_fortad_commit" || \
   test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$root/../fortad-lh030-clean.XXXXXX")
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
test -z "$(git -C "$fortad_repo" status --porcelain)"

mkdir -p "$out/include" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/port" "$out/mod"
ln -s "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/include/DIFFSIZES.inc"

compile_fixed() {
    local source=$1 label=$2 include_dir=${3:-}
    local -a flags=("${strict_fixed[@]}")
    if test -n "$include_dir"; then
        flags+=("-I$include_dir")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$out/$label.o" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    return "$status"
}

compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    return "$status"
}

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
if test ! -x "$tapenade_repo/bin/tapenade" || \
   test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

upstream_start=$(date +%s.%N)
compile_fixed "$source_dir/program.f" upstream_primal
compile_fixed "$source_dir/program_p.f" upstream_primal_port
compile_fixed "$source_dir/program_d.f" upstream_tangent
compile_fixed "$source_dir/program_b.f" upstream_reverse
compile_fixed "$source_dir/program_dv.f" upstream_multidirectional "$out/include"
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

tapenade_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -o lh030 "$source_dir/program.f") \
    >"$out/tapenade/parser.stdout" 2>"$out/tapenade/parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -o lh030 "$source_dir/program.f") \
    >"$out/tapenade/forward.stdout" 2>"$out/tapenade/forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -o lh030 "$source_dir/program.f") \
    >"$out/tapenade/reverse.stdout" 2>"$out/tapenade/reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

for generated in "$out/tapenade/parser/lh030_p.f" \
                 "$out/tapenade/forward/lh030_d.f" \
                 "$out/tapenade/reverse/lh030_b.f"; do
    test -s "$generated"
done
compile_fixed "$out/tapenade/parser/lh030_p.f" tapenade_parser
compile_fixed "$out/tapenade/forward/lh030_d.f" tapenade_forward
compile_fixed "$out/tapenade/reverse/lh030_b.f" tapenade_reverse

probe_exact_refusal() {
    local mode=$1 output=$2
    local -a mode_args=(--mode "$mode" --indep i1,i2 --proc head
        --name "lh030_exact_${mode}" --module "lh030_exact_${mode}_ad"
        --output "$output")
    if test "$mode" = reverse; then
        mode_args+=(--dep o)
    fi
    set +e
    (cd "$fortad_repo" && fo exec --no-build fortad "${mode_args[@]}" \
        "$source_dir/program.f") >"$out/fortad-exact-$mode.log" 2>&1
    local status=$?
    set -e
    test "$status" -ne 0
    grep -Fq 'fortad: unsupported statement at line 2' \
        "$out/fortad-exact-$mode.log"
    test ! -e "$output"
    printf '%s\n' "$status" >"$out/fortad-exact-$mode.status"
}

fortad_exact_start=$(date +%s.%N)
probe_exact_refusal forward "$out/fortad-exact-forward.f90"
probe_exact_refusal reverse "$out/fortad-exact-reverse.f90"
fortad_exact_stop=$(date +%s.%N)
fortad_exact_seconds=$(awk -v a="$fortad_exact_start" -v b="$fortad_exact_stop" \
    'BEGIN {printf "%.6f", b-a}')

fortad_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
    --indep i1,i2 --proc set01_lh030 --name lh030_forward \
    --module lh030_forward_ad --output "$out/port/lh030_forward.f90" \
    "$case_dir/port.f90") >"$out/fortad-port-forward.log" 2>&1
(cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
    --indep i1,i2 --dep o --proc set01_lh030 --name lh030_reverse \
    --module lh030_reverse_ad --output "$out/port/lh030_reverse.f90" \
    "$case_dir/port.f90") >"$out/fortad-port-reverse.log" 2>&1
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')
test -s "$out/port/lh030_forward.f90"
test -s "$out/port/lh030_reverse.f90"

compile_free "$case_dir/port.f90" port
compile_free "$case_dir/hand.f90" hand
compile_free "$out/port/lh030_forward.f90" fortad_forward
compile_free "$out/port/lh030_reverse.f90" fortad_reverse
compile_free "$case_dir/harness.f90" harness

compile_start=$(date +%s.%N)
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" \
    -o "$out/bench" "$out/port.o" "$out/hand.o" \
    "$out/fortad_forward.o" "$out/fortad_reverse.o" "$out/harness.o" \
    >"$out/link.stdout" 2>"$out/link.stderr"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
run_status=$?
set -e
test "$run_status" -eq 0
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh030\n'
    printf 'classification: runnable-ported-with-exact-source-fortad-refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'upstream_exact_source_compile: pass\n'
    printf 'upstream_stored_references_strict_compile: program_p.f=pass program_d.f=pass program_b.f=pass program_dv.f=pass\n'
    printf 'stored_multidirectional_include: pinned nonRegressions/DIFFSIZES.f as DIFFSIZES.inc\n'
    printf 'tapenade_fresh_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile: parser=pass tangent=pass reverse=pass\n'
    printf 'fortad_exact_probe_seconds: %s\n' "$fortad_exact_seconds"
    printf 'fortad_exact_result: expected-refusal forward_status=%s reverse_status=%s diagnostic="fortad: unsupported statement at line 2 (COMMON /zz/)"\n' \
        "$(cat "$out/fortad-exact-forward.status")" \
        "$(cat "$out/fortad-exact-reverse.status")"
    printf 'fortad_port_transform_seconds: %s\n' "$fortad_seconds"
    printf 'fortad_port_result: pass-transform-compile-runtime\n'
    printf 'port_compile_seconds: %s\n' "$compile_seconds"
    printf 'independent_oracle: closed-form hand JVP/VJP, central finite differences, and adjoint identity\n'
    cat "$out/run.txt"
    printf 'oracle_status: pass\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_dv.msg program_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh030/manifest.toml \
        cases/tapenade-set01/lh030/notes.md cases/tapenade-set01/lh030/port.f90 \
        cases/tapenade-set01/lh030/hand.f90 cases/tapenade-set01/lh030/harness.f90 \
        cases/tapenade-set01/lh030/run.sh cases/tapenade-set01/lh030/test_contract.py)
} >"$result"
cat "$result"
