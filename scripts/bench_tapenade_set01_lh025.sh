#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set01/lh025 case.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh025_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fortad_checkout="$fortad_repo"
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
strict_free=(-std=f2018 -pedantic-errors -ffree-line-length-none -O2 -fno-lto)
upstream_dir="$tapenade_repo/nonRegressions/set01/lh025"

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -s "$upstream_dir/program.f"
test -s "$upstream_dir/program_d.f"
test -s "$upstream_dir/program_b.f"
test -s "$upstream_dir/program_dv.f"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh025.XXXXXX)
clean_fortad_repo=
cleanup() {
    find "$out" -depth -type f -delete
    find "$out" -depth -type l -delete
    find "$out" -depth -type d -empty -delete
    if test -n "$clean_fortad_repo"; then
        rm -rf "$clean_fortad_repo"
    fi
}
trap cleanup EXIT

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)
if test "$fortad_original_commit" != "$required_fortad_commit" || \
        test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$root/../fortad-lh025-clean.XXXXXX")
    git clone --shared --quiet "$fortad_checkout" "$clean_fortad_repo"
    git -C "$clean_fortad_repo" checkout --detach --quiet "$required_fortad_commit"
    fortad_repo="$clean_fortad_repo"
fi
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"

mkdir -p "$root/results"
mkdir -p "$out/include" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/mod"
ln -sfn "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/include/DIFFSIZES.inc"

compile_source() {
    local source=$1 label=$2 flags_name=$3 include_dir=${4:-}
    local -a flags
    if test "$flags_name" = fixed; then
        flags=("${strict_fixed[@]}")
    else
        flags=("${strict_free[@]}" "-J$out/mod" "-I$out/mod")
    fi
    if test -n "$include_dir"; then
        flags+=("-I$include_dir")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$out/$label.o" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    test "$status" -eq 0
}

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

upstream_start=$(date +%s.%N)
compile_source "$upstream_dir/program.f" upstream_program fixed
compile_source "$upstream_dir/program_d.f" upstream_program_d fixed
compile_source "$upstream_dir/program_b.f" upstream_program_b fixed
compile_source "$upstream_dir/program_dv.f" upstream_program_dv fixed "$out/include"
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

tapenade_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -o lh025 "$upstream_dir/program.f") \
    >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -o lh025 "$upstream_dir/program.f") \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -o lh025 "$upstream_dir/program.f") \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_source "$out/tapenade/parser/lh025_p.f" tapenade_parser fixed
compile_source "$out/tapenade/forward/lh025_d.f" tapenade_forward fixed
compile_source "$out/tapenade/reverse/lh025_b.f" tapenade_reverse fixed

probe_exact_refusal() {
    local mode=$1 output=$2
    local -a mode_args
    if test "$mode" = forward; then
        mode_args=(--mode forward --indep a,x,lambda)
    else
        mode_args=(--mode reverse --indep a,x,lambda --dep y)
    fi
    set +e
    (cd "$fortad_repo" && fo exec --no-build fortad "${mode_args[@]}" \
        --proc funeval --name "lh025_exact_${mode}" \
        --module "lh025_exact_${mode}_ad" --output "$output" \
        "$upstream_dir/program.f") >"$out/fortad-exact-$mode.stdout" \
        2>"$out/fortad-exact-$mode.stderr"
    local status=$?
    set -e
    test "$status" -ne 0
    grep -Fq 'fortad: unsupported statement at line 73' \
        "$out/fortad-exact-$mode.stderr"
    printf '%s\n' "$status" >"$out/fortad-exact-$mode.status"
}

fortad_exact_start=$(date +%s.%N)
probe_exact_refusal forward "$out/lh025_exact_forward.f90"
probe_exact_refusal reverse "$out/lh025_exact_reverse.f90"
fortad_exact_stop=$(date +%s.%N)
fortad_exact_seconds=$(awk -v a="$fortad_exact_start" -v b="$fortad_exact_stop" \
    'BEGIN {printf "%.6f", b-a}')

fortad_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
    --indep a,x,lambda --proc set01_lh025 --name lh025_jvp \
    --module lh025_forward_ad --output "$out/lh025_forward.f90" \
    "$case_dir/lh025.f90") >"$out/fortad-forward.stdout" \
    2>"$out/fortad-forward.stderr"
(cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
    --indep a,x,lambda --dep y --proc set01_lh025 --name lh025_vjp \
    --module lh025_reverse_ad --output "$out/lh025_reverse.f90" \
    "$case_dir/lh025.f90") >"$out/fortad-reverse.stdout" \
    2>"$out/fortad-reverse.stderr"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
compile_source "$case_dir/lh025.f90" port free
compile_source "$case_dir/hand_derivatives_lh025.f90" hand free
compile_source "$out/lh025_forward.f90" fortad_forward free
compile_source "$out/lh025_reverse.f90" fortad_reverse free
compile_source "$root/harness/bench_tapenade_set01_lh025.f90" harness free
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/port.o" "$out/hand.o" "$out/fortad_forward.o" \
    "$out/fortad_reverse.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
run_status=$?
set -e
test "$run_status" -eq 0
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh025\n'
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
    if test "$fortad_original_commit" != "$required_fortad_commit" || \
            test -n "$fortad_dirty_paths"; then
        printf 'fortad_worktree: clean temporary clone pinned to required commit\n'
        printf 'fortad_original_commit: %s\n' "$fortad_original_commit"
        if test -n "$fortad_dirty_paths"; then
            printf 'fortad_original_dirty_paths: %s\n' "$(printf '%s' "$fortad_dirty_paths" | tr '\n' ';')"
        fi
    else
        printf 'fortad_worktree: supplied checkout clean\n'
    fi
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'upstream_exact_source_compile_statuses: program.f=%s program_d.f=%s program_b.f=%s program_dv.f=%s\n' \
        "$(cat "$out/upstream_program.status")" \
        "$(cat "$out/upstream_program_d.status")" \
        "$(cat "$out/upstream_program_b.status")" \
        "$(cat "$out/upstream_program_dv.status")"
    printf 'stored_multidirectional_include: pinned nonRegressions/DIFFSIZES.f as DIFFSIZES.inc\n'
    printf 'tapenade_fresh_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade_parser.status")" \
        "$(cat "$out/tapenade_forward.status")" \
        "$(cat "$out/tapenade_reverse.status")"
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated and strictly compiled\n'
    printf 'fortad_exact_probe_seconds: %s\n' "$fortad_exact_seconds"
    printf 'fortad_exact_result: expected-refusal forward_status=%s reverse_status=%s diagnostic="fortad: unsupported statement at line 73"\n' \
        "$(cat "$out/fortad-exact-forward.status")" \
        "$(cat "$out/fortad-exact-reverse.status")"
    printf 'fortad_port_transform_seconds: %s\n' "$fortad_seconds"
    printf 'fortad_port_generated_compile: forward=%s reverse=%s\n' \
        "$(cat "$out/fortad_forward.status")" \
        "$(cat "$out/fortad_reverse.status")"
    printf 'fortad_port_result: pass-transform-compile-runtime\n'
    printf 'fortad_oracle_scope: bounded standard-conforming N=7 K=3 port; exact source remains generic\n'
    printf 'independent_oracle: closed-form JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh025.f90 \
        cases/tapenade-set01/hand_derivatives_lh025.f90 \
        cases/tapenade-set01/tranche-lh025-manifest.toml \
        cases/tapenade-set01/tranche-lh025.md \
        harness/bench_tapenade_set01_lh025.f90 \
        scripts/bench_tapenade_set01_lh025.sh \
        scripts/test_tapenade_set01_lh025.py)
    printf 'upstream_source_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        nonRegressions/set01/lh025/program.f \
        nonRegressions/set01/lh025/program_d.f \
        nonRegressions/set01/lh025/program_b.f \
        nonRegressions/set01/lh025/program_dv.f)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
