#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh029 with exact-source, fresh-engine,
# and bounded-port evidence.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh029_validation.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -pedantic-errors -ffixed-form -ffixed-line-length-none \
             -Wall -Wextra -Wimplicit-interface)
compile_free=(-std=f2018 -pedantic-errors -ffree-form -ffree-line-length-none \
              -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
upstream_dir="$tapenade_repo/nonRegressions/set01/lh029"

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test -d "$fortad_checkout/.git" || test -f "$fortad_checkout/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_d.f program_b.f program_dv.f \
    program_b.msg program_d.msg program_dv.msg; do
    test -s "$upstream_dir/$source"
done

mkdir -p "$root/results"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh029.XXXXXX)
clean_fortad_repo=
cleanup() {
    find "$out" -depth -type f -delete
    find "$out" -depth -type l -delete
    find "$out" -depth -type d -empty -delete
    if test -n "$clean_fortad_repo"; then
        find "$clean_fortad_repo" -depth -type f -delete
        find "$clean_fortad_repo" -depth -type l -delete
        find "$clean_fortad_repo" -depth -type d -empty -delete
    fi
}
trap cleanup EXIT

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_original_dirty=$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)
fortad_repo="$fortad_checkout"
if test "$fortad_original_commit" != "$required_fortad_commit" || \
        test -n "$fortad_original_dirty"; then
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_checkout")/fortad-lh029-clean.XXXXXX")
    git clone --shared --quiet "$fortad_checkout" "$clean_fortad_repo"
    git -C "$clean_fortad_repo" checkout --detach --quiet "$required_fortad_commit"
    fortad_repo="$clean_fortad_repo"
fi
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"

mkdir -p "$out/include" "$out/mod" \
    "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" \
    "$out/exact" "$out/port"
cp "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/include/DIFFSIZES.inc"

(cd "$fortad_repo" && FO_JOBS=1 fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
test -x "$tapenade"

compile_capture() {
    local source=$1 object=$2 status_file=$3 form=$4
    local -a flags
    if test "$form" = fixed; then
        flags=("${strict_fixed[@]}" "-I$out/include")
    else
        flags=("${compile_free[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" \
        >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
    printf '%s\n' "$status"
}

upstream_start=$(date +%s.%N)
upstream_program_status=$(compile_capture "$upstream_dir/program.f" \
    "$out/upstream-program.o" "$out/upstream-program.status" fixed)
upstream_d_status=$(compile_capture "$upstream_dir/program_d.f" \
    "$out/upstream-program_d.o" "$out/upstream-program_d.status" fixed)
upstream_b_status=$(compile_capture "$upstream_dir/program_b.f" \
    "$out/upstream-program_b.o" "$out/upstream-program_b.status" fixed)
upstream_dv_status=$(compile_capture "$upstream_dir/program_dv.f" \
    "$out/upstream-program_dv.o" "$out/upstream-program_dv.status" fixed)
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')
for status in "$upstream_program_status" "$upstream_d_status" \
    "$upstream_b_status" "$upstream_dv_status"; do
    test "$status" = 0
done

tapenade_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -O . -o lh029 \
    "$upstream_dir/program.f") >"$out/tapenade/parser.stdout" \
    2>"$out/tapenade/parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -root s1 -O . -o lh029 \
    "$upstream_dir/program.f") >"$out/tapenade/forward.stdout" \
    2>"$out/tapenade/forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -root s1 -O . -o lh029 \
    "$upstream_dir/program.f") >"$out/tapenade/reverse.stdout" \
    2>"$out/tapenade/reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

tapenade_parser_status=$(compile_capture \
    "$out/tapenade/parser/lh029_p.f" "$out/tapenade/parser.o" \
    "$out/tapenade/parser.status" fixed)
tapenade_forward_status=$(compile_capture \
    "$out/tapenade/forward/lh029_d.f" "$out/tapenade/forward.o" \
    "$out/tapenade/forward.status" fixed)
tapenade_reverse_status=$(compile_capture \
    "$out/tapenade/reverse/lh029_b.f" "$out/tapenade/reverse.o" \
    "$out/tapenade/reverse.status" fixed)
for status in "$tapenade_parser_status" "$tapenade_forward_status" \
    "$tapenade_reverse_status"; do
    test "$status" = 0
done

fortad_exec() {
    (cd "$fortad_repo" && FO_JOBS=1 fo exec --no-build fortad "$@")
}

probe_exact() {
    local mode=$1 output=$2
    set +e
    if test "$mode" = forward; then
        fortad_exec --mode forward --indep T,z --proc s1 --name lh029_exact_jvp \
            --module lh029_exact_forward_ad --output "$output" "$upstream_dir/program.f" \
            >"$out/exact/forward.stdout" 2>"$out/exact/forward.stderr"
    else
        fortad_exec --mode reverse --indep T,z --dep xx --proc s1 --name lh029_exact_vjp \
            --module lh029_exact_reverse_ad --output "$output" "$upstream_dir/program.f" \
            >"$out/exact/reverse.stdout" 2>"$out/exact/reverse.stderr"
    fi
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/exact/$mode.status"
    test "$status" = 1
    test ! -e "$output"
    grep -Fq 'fortad: inlining s2 needs plain variables as arguments, because it may write to them' \
        "$out/exact/$mode.stderr"
}

fortad_exact_start=$(date +%s.%N)
probe_exact forward "$out/exact/forward.f90"
probe_exact reverse "$out/exact/reverse.f90"
fortad_exact_stop=$(date +%s.%N)
fortad_exact_seconds=$(awk -v a="$fortad_exact_start" -v b="$fortad_exact_stop" \
    'BEGIN {printf "%.6f", b-a}')

fortad_start=$(date +%s.%N)
fortad_exec --mode forward --indep t,z --proc set01_lh029 --name lh029_jvp \
    --module lh029_forward_ad --output "$out/port/forward.f90" \
    "$case_dir/lh029.f90" >"$out/port/forward.stdout" \
    2>"$out/port/forward.stderr"
fortad_exec --mode reverse --indep t,z --dep xx --proc set01_lh029 \
    --name lh029_xx_vjp --module lh029_xx_reverse_ad \
    --output "$out/port/xx_reverse.f90" "$case_dir/lh029.f90" \
    >"$out/port/xx.stdout" 2>"$out/port/xx.stderr"
fortad_exec --mode reverse --indep t,z --dep z_out --proc set01_lh029 \
    --name lh029_z_out_vjp --module lh029_z_out_reverse_ad \
    --output "$out/port/z_out_reverse.f90" "$case_dir/lh029.f90" \
    >"$out/port/z_out.stdout" 2>"$out/port/z_out.stderr"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')
for generated in "$out/port/forward.f90" "$out/port/xx_reverse.f90" \
    "$out/port/z_out_reverse.f90"; do
    test -s "$generated"
done

port_status=$(compile_capture "$case_dir/lh029.f90" "$out/port/port.o" \
    "$out/port/port.status" free)
hand_status=$(compile_capture "$case_dir/hand_derivatives_lh029.f90" \
    "$out/port/hand.o" "$out/port/hand.status" free)
forward_status=$(compile_capture "$out/port/forward.f90" \
    "$out/port/forward.o" "$out/port/forward.status" free)
xx_reverse_status=$(compile_capture "$out/port/xx_reverse.f90" \
    "$out/port/xx_reverse.o" "$out/port/xx_reverse.status" free)
z_out_reverse_status=$(compile_capture "$out/port/z_out_reverse.f90" \
    "$out/port/z_out_reverse.o" "$out/port/z_out_reverse.status" free)
harness_status=$(compile_capture "$root/harness/bench_tapenade_set01_lh029.f90" \
    "$out/port/harness.o" "$out/port/harness.status" free)
for status in "$port_status" "$hand_status" "$forward_status" \
    "$xx_reverse_status" "$z_out_reverse_status" "$harness_status"; do
    test "$status" = 0
done
"$fc" "${compile_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/port/bench" \
    "$out/port/port.o" "$out/port/hand.o" "$out/port/forward.o" \
    "$out/port/xx_reverse.o" "$out/port/z_out_reverse.o" \
    "$out/port/harness.o"

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/port/runtime-metrics.txt" "$out/port/bench" \
    >"$out/port/run.txt" 2>"$out/port/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/port/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh029\n'
    printf 'classification: runnable-ported-with-exact-source-fortad-refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'compile_free_flags: %s\n' "${compile_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_original_commit: %s\n' "$fortad_original_commit"
    printf 'fortad_original_dirty: %s\n' "${fortad_original_dirty:-clean}"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'upstream_program_strict_compile_status: %s\n' "$upstream_program_status"
    printf 'upstream_program_d_strict_compile_status: %s\n' "$upstream_d_status"
    printf 'upstream_program_b_strict_compile_status: %s\n' "$upstream_b_status"
    printf 'upstream_program_dv_strict_compile_status: %s\n' "$upstream_dv_status"
    printf 'stored_messages: program_b.msg program_d.msg program_dv.msg\n'
    printf 'tapenade_fresh_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_parser_strict_compile_status: %s\n' "$tapenade_parser_status"
    printf 'tapenade_forward_strict_compile_status: %s\n' "$tapenade_forward_status"
    printf 'tapenade_reverse_strict_compile_status: %s\n' "$tapenade_reverse_status"
    printf 'fortad_exact_probe_seconds: %s\n' "$fortad_exact_seconds"
    printf 'fortad_exact_forward_status: %s\n' "$(cat "$out/exact/forward.status")"
    printf 'fortad_exact_reverse_status: %s\n' "$(cat "$out/exact/reverse.status")"
    printf 'fortad_exact_diagnostic: inlining s2 needs plain variables as arguments, because it may write to them\n'
    printf 'fortad_port_transform_seconds: %s\n' "$fortad_seconds"
    printf 'fortad_port_forward_status: 0\n'
    printf 'fortad_port_reverse_xx_status: 0\n'
    printf 'fortad_port_reverse_z_out_status: 0\n'
    printf 'fortad_port_generated_compile_statuses: forward=%s reverse_xx=%s reverse_z_out=%s\n' \
        "$forward_status" "$xx_reverse_status" "$z_out_reverse_status"
    printf 'port_compile_statuses: port=%s hand=%s harness=%s\n' \
        "$port_status" "$hand_status" "$harness_status"
    printf 'port_contract: exactly seven t elements; nonzero z; 100-term constant V sum unrolled\n'
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/port/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        nonRegressions/set01/lh029/program.f \
        nonRegressions/set01/lh029/program_d.f \
        nonRegressions/set01/lh029/program_b.f \
        nonRegressions/set01/lh029/program_dv.f \
        nonRegressions/set01/lh029/program_b.msg \
        nonRegressions/set01/lh029/program_d.msg \
        nonRegressions/set01/lh029/program_dv.msg \
        nonRegressions/DIFFSIZES.f)
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh029.f90 \
        cases/tapenade-set01/hand_derivatives_lh029.f90 \
        cases/tapenade-set01/lh029-manifest.toml \
        cases/tapenade-set01/lh029.md \
        harness/bench_tapenade_set01_lh029.f90 \
        scripts/bench_tapenade_set01_lh029.sh \
        scripts/test_tapenade_set01_lh029.py)
    printf 'oracle_output:\n'
    cat "$out/port/run.txt"
} >"$result"
cat "$result"
