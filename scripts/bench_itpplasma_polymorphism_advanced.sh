#!/usr/bin/env bash
# Generate, check, and measure two advanced runtime-polymorphism JVPs.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
suite_out="$root/build/itpplasma-polymorphism-advanced"
mod_dir="$suite_out/mod"
result="$root/results/itpplasma_polymorphism_advanced_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
required_fortad_commit=1e5694c817803445edc1333edef8235a764fe098
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

mkdir -p "$mod_dir" "$root/results"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$suite_out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

run_case() {
    local case_id=$1
    local case_rel=$2
    local primal_proc=$3
    local generated_proc=$4
    local generated_module=$5
    local case_dir="$root/$case_rel"
    local case_out="$suite_out/$case_id"
    local transform_start transform_stop transform_seconds
    local case_compile_start case_compile_stop case_compile_seconds
    local generated_compile_start generated_compile_stop
    local generated_compile_seconds source_bytes object_bytes
    local object_text_bytes vectorized_loops optimized_messages missed_messages

    mkdir -p "$case_out"

    transform_start=$(date +%s.%N)
    (
        cd "$fortad_repo"
        fo exec --no-build fortad --mode forward --indep x \
            --proc "$primal_proc" --name "$generated_proc" \
            --module "$generated_module" \
            --output "$case_out/generated_jvp.f90" "$case_dir/primal.f90"
    ) >"$case_out/transform.stdout" 2>"$case_out/transform.stderr"
    transform_stop=$(date +%s.%N)
    transform_seconds=$(awk -v a="$transform_start" -v b="$transform_stop" \
        'BEGIN {printf "%.6f", b-a}')

    rm -f "$case_out/generated_optimization.txt"
    case_compile_start=$(date +%s.%N)
    "$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
        -c "$case_dir/primal.f90" -o "$case_out/primal.o"
    generated_compile_start=$(date +%s.%N)
    "$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
        -fopt-info-all="$case_out/generated_optimization.txt" \
        -c "$case_out/generated_jvp.f90" -o "$case_out/generated_jvp.o"
    generated_compile_stop=$(date +%s.%N)
    generated_compile_seconds=$(awk -v a="$generated_compile_start" \
        -v b="$generated_compile_stop" 'BEGIN {printf "%.6f", b-a}')
    "$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
        -c "$case_dir/hand_jvp.f90" -o "$case_out/hand_jvp.o"
    case_compile_stop=$(date +%s.%N)
    case_compile_seconds=$(awk -v a="$case_compile_start" \
        -v b="$case_compile_stop" 'BEGIN {printf "%.6f", b-a}')

    source_bytes=$(wc -c <"$case_out/generated_jvp.f90")
    object_bytes=$(stat -c '%s' "$case_out/generated_jvp.o")
    object_text_bytes=$(size -A "$case_out/generated_jvp.o" | \
        awk '$1 == ".text" {print $2}')
    vectorized_loops=$(grep -c 'loop vectorized' \
        "$case_out/generated_optimization.txt" || true)
    optimized_messages=$(grep -c 'optimized:' \
        "$case_out/generated_optimization.txt" || true)
    missed_messages=$(grep -c 'missed:' \
        "$case_out/generated_optimization.txt" || true)

    {
        printf 'case_id: %s\n' "$case_id"
        printf 'ad_transform_seconds: %s\n' "$transform_seconds"
        printf 'case_objects_compile_seconds: %s\n' "$case_compile_seconds"
        printf 'generated_object_compile_seconds: %s\n' \
            "$generated_compile_seconds"
        printf 'generated_source_bytes: %s\n' "$source_bytes"
        printf 'generated_object_bytes: %s\n' "$object_bytes"
        printf 'generated_object_text_bytes: %s\n' "$object_text_bytes"
        printf 'generated_vectorized_loop_messages: %s\n' "$vectorized_loops"
        printf 'generated_optimized_messages: %s\n' "$optimized_messages"
        printf 'generated_missed_optimization_messages: %s\n' "$missed_messages"
        printf 'optimization_report: build/itpplasma-polymorphism-advanced/%s/' \
            "$case_id"
        printf 'generated_optimization.txt\n'
        printf 'optimization_diagnostic:\n'
        sed "s#$root/##g" "$case_out/generated_optimization.txt"
    } >"$case_out/metrics.txt"
}

run_case class-is-default cases/itpplasma/class_is_default \
    evaluate_hierarchy evaluate_hierarchy_jvp class_is_default_ad
run_case factory-allocatable cases/itpplasma/factory_allocatable \
    evaluate_profile evaluate_profile_jvp factory_allocatable_ad

link_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/harness/bench_polymorphism_advanced.f90" \
    -o "$suite_out/harness.o"
"$fc" "${compile_flags[@]}" -o "$suite_out/bench" \
    "$suite_out/class-is-default/primal.o" \
    "$suite_out/class-is-default/generated_jvp.o" \
    "$suite_out/class-is-default/hand_jvp.o" \
    "$suite_out/factory-allocatable/primal.o" \
    "$suite_out/factory-allocatable/generated_jvp.o" \
    "$suite_out/factory-allocatable/hand_jvp.o" "$suite_out/harness.o"
link_stop=$(date +%s.%N)
link_seconds=$(awk -v a="$link_start" -v b="$link_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$suite_out/runtime_metrics.txt" "$suite_out/bench" \
    >"$suite_out/run.txt" 2>"$suite_out/run.stderr"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)

{
    printf 'suite: itpplasma advanced runtime polymorphism JVPs\n'
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
    printf 'shared_harness_compile_and_link_seconds: %s\n' "$link_seconds"
    cat "$suite_out/runtime_metrics.txt"
    printf 'transform_method: date +%%s.%%N around fo exec --no-build; engine '
    printf 'setup is timed separately\n'
    printf 'runtime_method: Fortran system_clock over 10000000 dispatches per '
    printf 'case and implementation; /usr/bin/time %%e and %%M wrap the suite\n'
    printf 'oracle: hand-derived child JVPs plus fixed numerical expectations; '
    printf 'generated source text is not inspected\n'
    printf 'factory_scope: two allocate(source=...) calls occur outside the hot '
    printf 'loops for each timed implementation\n'
    printf 'optimization_note: both kernels are scalar; zero vectorized loops is '
    printf 'expected and complete compiler reports follow\n'
    printf '\n'
    cat "$suite_out/class-is-default/metrics.txt"
    printf '\n'
    cat "$suite_out/factory-allocatable/metrics.txt"
    printf '\nsource_sha256:\n'
    (
        cd "$root"
        sha256sum cases/itpplasma/class_is_default/primal.f90 \
            cases/itpplasma/class_is_default/hand_jvp.f90 \
            cases/itpplasma/factory_allocatable/primal.f90 \
            cases/itpplasma/factory_allocatable/hand_jvp.f90 \
            harness/bench_polymorphism_advanced.f90 \
            scripts/bench_itpplasma_polymorphism_advanced.sh
    )
    printf 'run_output:\n'
    cat "$suite_out/run.txt"
} >"$result"

cat "$result"
