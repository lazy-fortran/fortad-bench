#!/usr/bin/env bash
# Exercise optional/keyword, generic-rank, and complex arithmetic boundaries.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
suite_out="$root/build/itpplasma-interfaces"
mod_dir="$suite_out/mod"
result="$root/results/itpplasma_interfaces_validation.txt"
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

mkdir -p "$mod_dir" "$suite_out/optional" "$suite_out/generic" \
    "$suite_out/optional-keyword" "$suite_out/generic-rank" \
    "$suite_out/complex" "$root/results"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$suite_out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

run_refusal() {
    local case_id=$1 case_rel=$2 proc=$3 module=$4
    local case_dir="$root/$case_rel" case_out="$suite_out/$case_id"
    local output="$case_out/generated_jvp.f90" status
    set +e
    (
        cd "$fortad_repo"
        fo exec --no-build fortad --mode forward --indep x \
            --proc "$proc" --name "${proc}_jvp" --module "$module" \
            --output "$output" "$case_dir/primal.f90"
    ) >"$case_out/transform.stdout" 2>"$case_out/transform.stderr"
    status=$?
    set -e
    test "$status" -ne 0
    grep -Fq 'fortad: unsupported expression' "$case_out/transform.stderr"
    test ! -e "$output"
    printf '%s\n' "$status" >"$case_out/status"
}

run_refusal generic-rank cases/itpplasma/generic_dispatch \
    evaluate_generic generic_dispatch_ad

optional_transform_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep x \
        --proc evaluate_optional --name evaluate_optional_jvp \
        --module optional_keyword_ad \
        --output "$suite_out/optional/generated_jvp.f90" \
        "$root/cases/itpplasma/optional_keyword/primal.f90"
) >"$suite_out/optional/transform.stdout" \
    2>"$suite_out/optional/transform.stderr"
optional_transform_stop=$(date +%s.%N)
optional_transform_seconds=$(awk -v a="$optional_transform_start" \
    -v b="$optional_transform_stop" 'BEGIN {printf "%.6f", b-a}')

complex_transform_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep zr,zi \
        --proc evaluate_complex --name evaluate_complex_jvp \
        --module complex_real_jacobian_ad \
        --output "$suite_out/complex/generated_jvp.f90" \
        "$root/cases/itpplasma/complex_real_jacobian/primal.f90"
) >"$suite_out/complex/transform.stdout" \
    2>"$suite_out/complex/transform.stderr"
complex_transform_stop=$(date +%s.%N)
complex_transform_seconds=$(awk -v a="$complex_transform_start" -v b="$complex_transform_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/cases/itpplasma/optional_keyword/primal.f90" \
    -o "$suite_out/optional/primal.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/cases/itpplasma/optional_keyword/hand_jvp.f90" \
    -o "$suite_out/optional/hand_jvp.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/cases/itpplasma/generic_dispatch/primal.f90" \
    -o "$suite_out/generic/primal.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/cases/itpplasma/generic_dispatch/hand_jvp.f90" \
    -o "$suite_out/generic/hand_jvp.o"
generated_compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -fopt-info-all="$suite_out/optional/generated_optimization.txt" \
    -c "$suite_out/optional/generated_jvp.f90" \
    -o "$suite_out/optional/generated_jvp.o"
optional_generated_compile_stop=$(date +%s.%N)
optional_generated_compile_seconds=$(awk -v a="$generated_compile_start" \
    -v b="$optional_generated_compile_stop" 'BEGIN {printf "%.6f", b-a}')
generated_compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -fopt-info-all="$suite_out/complex/generated_optimization.txt" \
    -c "$suite_out/complex/generated_jvp.f90" \
    -o "$suite_out/complex/generated_jvp.o"
generated_compile_stop=$(date +%s.%N)
generated_compile_seconds=$(awk -v a="$generated_compile_start" \
    -v b="$generated_compile_stop" 'BEGIN {printf "%.6f", b-a}')
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/cases/itpplasma/complex_real_jacobian/primal.f90" \
    -o "$suite_out/complex/primal.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/cases/itpplasma/complex_real_jacobian/hand_jvp.f90" \
    -o "$suite_out/complex/hand_jvp.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/harness/bench_interfaces.f90" -o "$suite_out/harness.o"
"$fc" "${compile_flags[@]}" -o "$suite_out/bench" \
    "$suite_out/optional/primal.o" "$suite_out/optional/hand_jvp.o" \
    "$suite_out/optional/generated_jvp.o" \
    "$suite_out/generic/primal.o" "$suite_out/generic/hand_jvp.o" \
    "$suite_out/complex/primal.o" "$suite_out/complex/generated_jvp.o" \
    "$suite_out/complex/hand_jvp.o" "$suite_out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$suite_out/runtime_metrics.txt" "$suite_out/bench" \
    >"$suite_out/run.txt" 2>"$suite_out/run.stderr"

source_bytes=$(wc -c <"$suite_out/complex/generated_jvp.f90")
object_bytes=$(stat -c '%s' "$suite_out/complex/generated_jvp.o")
object_text_bytes=$(size -A "$suite_out/complex/generated_jvp.o" | \
    awk '$1 == ".text" {print $2}')
vectorized_loops=$(grep -c 'loop vectorized' \
    "$suite_out/complex/generated_optimization.txt" || true)
optimized_messages=$(grep -c 'optimized:' \
    "$suite_out/complex/generated_optimization.txt" || true)
missed_messages=$(grep -c 'missed:' \
    "$suite_out/complex/generated_optimization.txt" || true)

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: \
    '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= \
    '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)

{
    printf 'suite: itpplasma procedure-interface and complex boundaries\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(fo version)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_setup_seconds_cached_or_incremental: %s\n' "$setup_seconds"
    printf 'oracle: hand JVPs, central finite differences, and fixed values\n'
    printf 'discrete_contract: generic resolution and optional presence are fixed at the call site; real-coordinate complex path is fixed\n'
    printf '\ncase_id: optional-keyword\n'
    printf 'status: implemented\n'
    printf 'ad_transform_seconds: %s\n' "$optional_transform_seconds"
    printf 'generated_object_compile_seconds: %s\n' "$optional_generated_compile_seconds"
    printf 'generated_source_bytes: %s\n' "$(wc -c <"$suite_out/optional/generated_jvp.f90")"
    printf 'generated_object_bytes: %s\n' "$(stat -c '%s' "$suite_out/optional/generated_jvp.o")"
    printf 'optimization_report: build/itpplasma-interfaces/optional/generated_optimization.txt\n'
    printf '\ncase_id: generic-rank\n'
    printf 'status: expected-refusal\n'
    printf 'refusal_exit_status: %s\n' "$(cat "$suite_out/generic-rank/status")"
    printf 'diagnostic: fortad: unsupported expression (generic rank resolution)\n'
    cat "$suite_out/generic-rank/transform.stderr"
    printf '\ncase_id: complex-arithmetic-jvp\n'
    printf 'status: implemented\n'
    printf 'ad_transform_seconds: %s\n' "$complex_transform_seconds"
    printf 'case_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'generated_object_compile_seconds: %s\n' "$generated_compile_seconds"
    printf 'generated_source_bytes: %s\n' "$source_bytes"
    printf 'generated_object_bytes: %s\n' "$object_bytes"
    printf 'generated_object_text_bytes: %s\n' "$object_text_bytes"
    printf 'generated_vectorized_loop_messages: %s\n' "$vectorized_loops"
    printf 'generated_optimized_messages: %s\n' "$optimized_messages"
    printf 'generated_missed_optimization_messages: %s\n' "$missed_messages"
    cat "$suite_out/runtime_metrics.txt"
    printf 'optimization_report: build/itpplasma-interfaces/complex/generated_optimization.txt\n'
    printf '\nsource_sha256:\n'
    (
        cd "$root"
        sha256sum cases/itpplasma/optional_keyword/primal.f90 \
            cases/itpplasma/optional_keyword/hand_jvp.f90 \
            cases/itpplasma/generic_dispatch/primal.f90 \
            cases/itpplasma/generic_dispatch/hand_jvp.f90 \
            cases/itpplasma/complex_real_jacobian/primal.f90 \
            cases/itpplasma/complex_real_jacobian/hand_jvp.f90 \
            harness/bench_interfaces.f90 scripts/bench_itpplasma_interfaces.sh
    )
    printf 'run_output:\n'
    cat "$suite_out/run.txt"
} >"$result"

cat "$result"
