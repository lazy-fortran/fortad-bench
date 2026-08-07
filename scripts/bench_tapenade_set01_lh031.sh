#!/usr/bin/env bash
# Validate the pinned Tapenade nonRegressions/set01/lh031 case.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh031_validation.txt"
fortad_source=${FORTAD_REPO:-"$root/../fortad"}
default_tapenade_repo="$root/upstream/tapenade"
if test ! -d "$default_tapenade_repo"; then
    main_root=$(git -C "$root" worktree list --porcelain | awk 'NR == 1 {print $2}')
    if test -n "$main_root" && test -d "$main_root/upstream/tapenade"; then
        default_tapenade_repo="$main_root/upstream/tapenade"
    fi
fi
tapenade_repo=${TAPENADE_REPO:-"$default_tapenade_repo"}
fortad_source=$(cd "$fortad_source" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors \
              -Wall -Wextra -Wimplicit-interface)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
             -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
upstream_dir="$tapenade_repo/nonRegressions/set01/lh031"

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test -d "$fortad_source/.git" || test -f "$fortad_source/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for reference in program.f program_d.f program_b.f program_dv.f \
                program_d.msg program_b.msg program_dv.msg; do
    test -s "$upstream_dir/$reference"
done

mkdir -p "$root/results"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh031.XXXXXX)
fortad_repo=$(mktemp -d "$root/../fortad-lh031-clean.XXXXXX")
git clone --shared --quiet "$fortad_source" "$fortad_repo"
git -C "$fortad_repo" checkout --detach --quiet "$required_fortad_commit"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"

mkdir -p "$out/include" "$out/mod" "$out/tapenade/parser" \
    "$out/tapenade/forward" "$out/tapenade/reverse" "$out/exact" "$out/port"
ln -sfn "$tapenade_repo/nonRegressions/DIFFSIZES.f" \
    "$out/include/DIFFSIZES.inc"

compile_capture() {
    local input=$1 output=$2 status_file=$3 form=$4 include_dir=${5:-}
    local -a flags
    if test "$form" = fixed; then
        flags=("${strict_fixed[@]}")
    else
        flags=("${strict_free[@]}" "-J$out/mod" "-I$out/mod")
    fi
    if test -n "$include_dir"; then
        flags+=("-I$include_dir")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$input" -o "$output" \
        >"$output.stdout" 2>"$output.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
    return "$status"
}

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

build_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-build.stdout" \
    2>"$out/fortad-build.stderr"
build_stop=$(date +%s.%N)
build_seconds=$(awk -v a="$build_start" -v b="$build_stop" \
    'BEGIN {printf "%.6f", b-a}')

upstream_start=$(date +%s.%N)
compile_capture "$upstream_dir/program.f" "$out/upstream_program.o" \
    "$out/upstream_program.status" fixed
upstream_program_status=$?
compile_capture "$upstream_dir/program_d.f" "$out/upstream_program_d.o" \
    "$out/upstream_program_d.status" fixed
upstream_program_d_status=$?
compile_capture "$upstream_dir/program_b.f" "$out/upstream_program_b.o" \
    "$out/upstream_program_b.status" fixed
upstream_program_b_status=$?
compile_capture "$upstream_dir/program_dv.f" "$out/upstream_program_dv.o" \
    "$out/upstream_program_dv.status" fixed "$out/include"
upstream_program_dv_status=$?
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"
tapenade_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -o lh031 "$upstream_dir/program.f") \
    >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -o lh031 "$upstream_dir/program.f") \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -o lh031 "$upstream_dir/program.f") \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')
test -s "$out/tapenade/parser/lh031_p.f"
test -s "$out/tapenade/forward/lh031_d.f"
test -s "$out/tapenade/reverse/lh031_b.f"
compile_capture "$out/tapenade/parser/lh031_p.f" "$out/tapenade_parser.o" \
    "$out/tapenade_parser.status" fixed
tapenade_parser_status=$?
compile_capture "$out/tapenade/forward/lh031_d.f" "$out/tapenade_forward.o" \
    "$out/tapenade_forward.status" fixed
tapenade_forward_status=$?
compile_capture "$out/tapenade/reverse/lh031_b.f" "$out/tapenade_reverse.o" \
    "$out/tapenade_reverse.status" fixed
tapenade_reverse_status=$?

fortad_exact_start=$(date +%s.%N)
set +e
fortad_exec --mode forward --indep x,y,z --proc sub1 --name lh031_exact_jvp \
    --module lh031_exact_forward_ad --output "$out/exact/forward.f90" \
    "$upstream_dir/program.f" >"$out/exact/forward.stdout" \
    2>"$out/exact/forward.stderr"
fortad_exact_forward_status=$?
fortad_exec --mode reverse --indep x,y,z --dep x --proc sub1 --name lh031_exact_vjp \
    --module lh031_exact_reverse_ad --output "$out/exact/reverse.f90" \
    "$upstream_dir/program.f" >"$out/exact/reverse.stdout" \
    2>"$out/exact/reverse.stderr"
fortad_exact_reverse_status=$?
set -e
fortad_exact_stop=$(date +%s.%N)
fortad_exact_seconds=$(awk -v a="$fortad_exact_start" -v b="$fortad_exact_stop" \
    'BEGIN {printf "%.6f", b-a}')
test "$fortad_exact_forward_status" -eq 1
test "$fortad_exact_reverse_status" -eq 1
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
grep -Fq 'fortad: unsupported statement at line 9' \
    "$out/exact/forward.stderr"
grep -Fq 'fortad: unsupported statement at line 9' \
    "$out/exact/reverse.stderr"

fortad_port_start=$(date +%s.%N)
set +e
fortad_exec jvp x,y,z --proc set01_lh031 --name lh031_jvp \
    --module lh031_forward_ad --output "$out/port/lh031_forward.f90" \
    "$case_dir/lh031.f90" >"$out/port/forward.stdout" \
    2>"$out/port/forward.stderr"
fortad_port_forward_status=$?
for dep in x y z; do
    fortad_exec vjp x,y,z --dep "${dep}_out" --proc set01_lh031 \
        --name "lh031_vjp_${dep}" --module "lh031_reverse_${dep}" \
        --output "$out/port/lh031_reverse_${dep}.f90" \
        "$case_dir/lh031.f90" >"$out/port/reverse_${dep}.stdout" \
        2>"$out/port/reverse_${dep}.stderr"
    printf '%s\n' "$?" >"$out/port/reverse_${dep}.status"
done
fortad_port_reverse_x_status=$(cat "$out/port/reverse_x.status")
fortad_port_reverse_y_status=$(cat "$out/port/reverse_y.status")
fortad_port_reverse_z_status=$(cat "$out/port/reverse_z.status")
set -e
fortad_port_stop=$(date +%s.%N)
fortad_port_seconds=$(awk -v a="$fortad_port_start" -v b="$fortad_port_stop" \
    'BEGIN {printf "%.6f", b-a}')
test "$fortad_port_forward_status" -eq 0
test "$fortad_port_reverse_x_status" -eq 0
test "$fortad_port_reverse_y_status" -eq 0
test "$fortad_port_reverse_z_status" -eq 0
for generated in "$out/port/lh031_forward.f90" \
                 "$out/port/lh031_reverse_x.f90" \
                 "$out/port/lh031_reverse_y.f90" \
                 "$out/port/lh031_reverse_z.f90"; do
    test -s "$generated"
done

compile_start=$(date +%s.%N)
compile_capture "$case_dir/lh031.f90" "$out/port/primal.o" \
    "$out/port/primal.status" free
port_status=$?
compile_capture "$case_dir/hand_derivative_lh031.f90" "$out/port/hand.o" \
    "$out/port/hand.status" free
hand_status=$?
compile_capture "$out/port/lh031_forward.f90" "$out/port/forward.o" \
    "$out/port/forward.status" free
forward_status=$?
compile_capture "$out/port/lh031_reverse_x.f90" "$out/port/reverse_x.o" \
    "$out/port/reverse_x_compile.status" free
reverse_x_compile_status=$?
compile_capture "$out/port/lh031_reverse_y.f90" "$out/port/reverse_y.o" \
    "$out/port/reverse_y_compile.status" free
reverse_y_compile_status=$?
compile_capture "$out/port/lh031_reverse_z.f90" "$out/port/reverse_z.o" \
    "$out/port/reverse_z_compile.status" free
reverse_z_compile_status=$?
compile_capture "$root/harness/bench_tapenade_set01_lh031.f90" \
    "$out/port/harness.o" "$out/port/harness.status" free
harness_status=$?
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/port/bench" \
    "$out/port/primal.o" "$out/port/hand.o" "$out/port/forward.o" \
    "$out/port/reverse_x.o" "$out/port/reverse_y.o" "$out/port/reverse_z.o" \
    "$out/port/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/port/runtime-metrics.txt" "$out/port/bench" \
    >"$out/port/run.txt" 2>"$out/port/run.stderr"
run_status=$?
set -e
test "$run_status" -eq 0
grep -Fqx 'oracle_status: pass' "$out/port/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh031\n'
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
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_build_seconds: %s\n' "$build_seconds"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'upstream_program_strict_compile_status: %s\n' "$upstream_program_status"
    printf 'upstream_program_d_strict_compile_status: %s\n' "$upstream_program_d_status"
    printf 'upstream_program_b_strict_compile_status: %s\n' "$upstream_program_b_status"
    printf 'upstream_program_dv_strict_compile_status: %s\n' "$upstream_program_dv_status"
    printf 'stored_reference_messages: program_d.msg program_b.msg program_dv.msg\n'
    printf 'stored_multidirectional_include: pinned nonRegressions/DIFFSIZES.f as DIFFSIZES.inc\n'
    printf 'tapenade_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: fresh parser, tangent, and reverse pass\n'
    printf 'tapenade_parser_strict_compile_status: %s\n' "$tapenade_parser_status"
    printf 'tapenade_forward_strict_compile_status: %s\n' "$tapenade_forward_status"
    printf 'tapenade_reverse_strict_compile_status: %s\n' "$tapenade_reverse_status"
    printf 'fortad_exact_probe_seconds: %s\n' "$fortad_exact_seconds"
    printf 'fortad_exact_forward_status: %s\n' "$fortad_exact_forward_status"
    printf 'fortad_exact_reverse_status: %s\n' "$fortad_exact_reverse_status"
    printf 'fortad_exact_diagnostic: fortad: unsupported statement at line 9\n'
    printf 'fortad_port_transform_seconds: %s\n' "$fortad_port_seconds"
    printf 'fortad_port_forward_status: %s\n' "$fortad_port_forward_status"
    printf 'fortad_port_reverse_x_status: %s\n' "$fortad_port_reverse_x_status"
    printf 'fortad_port_reverse_y_status: %s\n' "$fortad_port_reverse_y_status"
    printf 'fortad_port_reverse_z_status: %s\n' "$fortad_port_reverse_z_status"
    printf 'fortad_port_generated_compile_statuses: forward=%s reverse_x=%s reverse_y=%s reverse_z=%s\n' \
        "$forward_status" "$reverse_x_compile_status" "$reverse_y_compile_status" \
        "$reverse_z_compile_status"
    printf 'port_compile_statuses: port=%s hand=%s harness=%s\n' \
        "$port_status" "$hand_status" "$harness_status"
    printf 'fortad_port_result: pass-transform-compile-runtime\n'
    printf 'compile_seconds: %s\n' "$compile_seconds"
    printf 'independent_oracle: closed-form JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/port/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        nonRegressions/set01/lh031/program.f \
        nonRegressions/set01/lh031/program_d.f \
        nonRegressions/set01/lh031/program_b.f \
        nonRegressions/set01/lh031/program_dv.f \
        nonRegressions/set01/lh031/program_d.msg \
        nonRegressions/set01/lh031/program_b.msg \
        nonRegressions/set01/lh031/program_dv.msg)
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh031.f90 \
        cases/tapenade-set01/hand_derivative_lh031.f90 \
        cases/tapenade-set01/lh031-manifest.toml \
        cases/tapenade-set01/lh031.md \
        harness/bench_tapenade_set01_lh031.f90 \
        scripts/bench_tapenade_set01_lh031.sh \
        scripts/test_tapenade_set01_lh031.py)
    printf 'oracle_output:\n'
    cat "$out/port/run.txt"
} >"$result"
cat "$result"
