#!/usr/bin/env bash
# Generate, check, and measure paired runtime-polymorphism JVP and VJP paths.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_rel=cases/itpplasma/polymorphic_select_type
case_dir="$root/$case_rel"
out="$root/build/itpplasma-polymorphic-select-type"
result="$root/results/itpplasma_polymorphic_select_type_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
required_fortad_commit=51e54576dac9f62a3629c2fc23f54ee6dd014a15
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
if ! git -C "$fortad_repo" merge-base --is-ancestor \
    "$required_fortad_commit" HEAD; then
    printf 'FortAD HEAD must contain %s\n' "$required_fortad_commit" >&2
    exit 1
fi

mkdir -p "$out/mod" "$root/results"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

forward_transform_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep x \
        --proc field_response --name field_response_jvp \
        --module polymorphic_select_type_ad \
        --output "$out/generated_jvp.f90" "$case_dir/primal.f90"
) >"$out/transform.stdout" 2>"$out/transform.stderr"
forward_transform_stop=$(date +%s.%N)
forward_transform_seconds=$(awk -v a="$forward_transform_start" \
    -v b="$forward_transform_stop" \
    'BEGIN {printf "%.6f", b-a}')

reverse_transform_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode reverse --indep x \
        --proc field_response --name field_response_vjp \
        --module polymorphic_select_type_reverse_ad \
        --output "$out/generated_vjp.f90" "$case_dir/primal.f90"
) >"$out/reverse_transform.stdout" 2>"$out/reverse_transform.stderr"
reverse_transform_stop=$(date +%s.%N)
reverse_transform_seconds=$(awk -v a="$reverse_transform_start" \
    -v b="$reverse_transform_stop" 'BEGIN {printf "%.6f", b-a}')

rm -f "$out/generated_jvp_optimization.txt" \
    "$out/generated_vjp_optimization.txt"
compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$case_dir/primal.f90" -o "$out/primal.o"
jvp_compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -fopt-info-all="$out/generated_jvp_optimization.txt" \
    -c "$out/generated_jvp.f90" -o "$out/generated_jvp.o"
jvp_compile_stop=$(date +%s.%N)
jvp_compile_seconds=$(awk -v a="$jvp_compile_start" \
    -v b="$jvp_compile_stop" 'BEGIN {printf "%.6f", b-a}')
vjp_compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -fopt-info-all="$out/generated_vjp_optimization.txt" \
    -c "$out/generated_vjp.f90" -o "$out/generated_vjp.o"
vjp_compile_stop=$(date +%s.%N)
vjp_compile_seconds=$(awk -v a="$vjp_compile_start" \
    -v b="$vjp_compile_stop" 'BEGIN {printf "%.6f", b-a}')
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$case_dir/hand_jvp.f90" -o "$out/hand_jvp.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$case_dir/hand_vjp.f90" -o "$out/hand_vjp.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$root/harness/bench_polymorphic_select_type.f90" \
    -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/bench" "$out/primal.o" \
    "$out/generated_jvp.o" "$out/generated_vjp.o" "$out/hand_jvp.o" \
    "$out/hand_vjp.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime_metrics.txt" "$out/bench" \
    >"$out/run.txt" 2>"$out/run.stderr"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
jvp_source_bytes=$(wc -c <"$out/generated_jvp.f90")
vjp_source_bytes=$(wc -c <"$out/generated_vjp.f90")
jvp_object_bytes=$(stat -c '%s' "$out/generated_jvp.o")
vjp_object_bytes=$(stat -c '%s' "$out/generated_vjp.o")
jvp_object_text_bytes=$(size -A "$out/generated_jvp.o" | \
    awk '$1 == ".text" {print $2}')
vjp_object_text_bytes=$(size -A "$out/generated_vjp.o" | \
    awk '$1 == ".text" {print $2}')
jvp_vectorized_loops=$(grep -c 'loop vectorized' \
    "$out/generated_jvp_optimization.txt" || true)
vjp_vectorized_loops=$(grep -c 'loop vectorized' \
    "$out/generated_vjp_optimization.txt" || true)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)

{
    printf 'case: itpplasma polymorphic SELECT TYPE JVP and VJP\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(fo version)"
    printf 'time_tool: %s\n' "$(/usr/bin/time --version | head -1)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_setup_seconds_cached_or_incremental: %s\n' "$setup_seconds"
    printf 'jvp_transform_seconds: %s\n' "$forward_transform_seconds"
    printf 'vjp_transform_seconds: %s\n' "$reverse_transform_seconds"
    printf 'generated_jvp_object_compile_seconds: %s\n' \
        "$jvp_compile_seconds"
    printf 'generated_vjp_object_compile_seconds: %s\n' \
        "$vjp_compile_seconds"
    printf 'case_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'generated_jvp_source_bytes: %s\n' "$jvp_source_bytes"
    printf 'generated_vjp_source_bytes: %s\n' "$vjp_source_bytes"
    printf 'generated_jvp_object_bytes: %s\n' "$jvp_object_bytes"
    printf 'generated_vjp_object_bytes: %s\n' "$vjp_object_bytes"
    printf 'generated_jvp_object_text_bytes: %s\n' "$jvp_object_text_bytes"
    printf 'generated_vjp_object_text_bytes: %s\n' "$vjp_object_text_bytes"
    cat "$out/runtime_metrics.txt"
    printf 'generated_jvp_vectorized_loop_messages: %s\n' \
        "$jvp_vectorized_loops"
    printf 'generated_vjp_vectorized_loop_messages: %s\n' \
        "$vjp_vectorized_loops"
    printf 'jvp_optimization_report: '
    printf 'build/itpplasma-polymorphic-select-type/'
    printf 'generated_jvp_optimization.txt\n'
    printf 'vjp_optimization_report: '
    printf 'build/itpplasma-polymorphic-select-type/'
    printf 'generated_vjp_optimization.txt\n'
    printf 'optimization_note: scalar dispatch kernel; zero vectorized loops is '
    printf 'expected and the complete compiler report is retained\n'
    printf 'jvp_optimization_diagnostic:\n'
    sed "s#$root/##g" "$out/generated_jvp_optimization.txt"
    printf 'vjp_optimization_diagnostic:\n'
    sed "s#$root/##g" "$out/generated_vjp_optimization.txt"
    printf 'transform_method: date +%%s.%%N around fo exec --no-build; engine '
    printf 'setup is timed separately\n'
    printf 'runtime_method: Fortran system_clock over 10000000 dispatches per '
    printf 'implementation; /usr/bin/time %%e and %%M wrap the executable\n'
    printf 'oracle: abstract deferred binding, hand JVP/VJP, central finite '
    printf 'differences, fixed values, and the adjoint identity for both '
    printf 'runtime children\n'
    printf 'discrete_contract: dynamic type is passive and fixed throughout each '
    printf 'derivative call; switching child type is outside the derivative; '
    printf 'the active input is scalar x\n'
    printf 'source_sha256:\n'
    (
        cd "$root"
        sha256sum "$case_rel/primal.f90" "$case_rel/hand_jvp.f90" \
            "$case_rel/hand_vjp.f90" \
            harness/bench_polymorphic_select_type.f90 \
            scripts/bench_itpplasma_polymorphic_select_type.sh
    )
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
