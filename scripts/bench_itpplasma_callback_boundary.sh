#!/usr/bin/env bash
# Check the procedure-pointer refusal and measure its SELECT TYPE replacement.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
suite_out="$root/build/itpplasma-callback-boundary"
mod_dir="$suite_out/mod"
refusal_dir="$root/cases/itpplasma/dynamic_callback_refusal"
positive_dir="$root/cases/itpplasma/callback_select_type"
result="$root/results/itpplasma_callback_boundary_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
required_fortad_commit=1e5694c817803445edc1333edef8235a764fe098
expected_diagnostic="fortad: no derivative rule for 'selected_callback'; register one with fad_add_rule, or keep it out of the active path"
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

mkdir -p "$mod_dir" "$suite_out/refusal" "$suite_out/positive" \
    "$root/results"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$suite_out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$refusal_dir/primal.f90" -o "$suite_out/refusal/primal.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/harness/check_dynamic_callback_primal.f90" \
    -o "$suite_out/refusal/harness.o"
"$fc" "${compile_flags[@]}" -o "$suite_out/refusal/check_primal" \
    "$suite_out/refusal/primal.o" "$suite_out/refusal/harness.o"
"$suite_out/refusal/check_primal" >"$suite_out/refusal/primal_run.txt"

rm -f "$suite_out/refusal/generated_jvp.f90"
set +e
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep x \
        --proc evaluate_dynamic --name evaluate_dynamic_jvp \
        --module dynamic_callback_ad \
        --output "$suite_out/refusal/generated_jvp.f90" \
        "$refusal_dir/primal.f90"
) >"$suite_out/refusal/transform.stdout" \
    2>"$suite_out/refusal/transform.stderr"
refusal_status=$?
set -e

if test "$refusal_status" -eq 0; then
    printf 'FortAD accepted the unsupported dynamic callback\n' >&2
    exit 1
fi
if ! grep -Fqx "$expected_diagnostic" \
    "$suite_out/refusal/transform.stderr"; then
    printf 'FortAD did not emit the expected callback diagnostic\n' >&2
    cat "$suite_out/refusal/transform.stderr" >&2
    exit 1
fi
if test -e "$suite_out/refusal/generated_jvp.f90"; then
    printf 'FortAD left a derivative file after refusing the callback\n' >&2
    exit 1
fi

transform_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep x \
        --proc evaluate_callback --name evaluate_callback_jvp \
        --module callback_select_type_ad \
        --output "$suite_out/positive/generated_jvp.f90" \
        "$positive_dir/primal.f90"
) >"$suite_out/positive/transform.stdout" \
    2>"$suite_out/positive/transform.stderr"
transform_stop=$(date +%s.%N)
transform_seconds=$(awk -v a="$transform_start" -v b="$transform_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$positive_dir/primal.f90" -o "$suite_out/positive/primal.o"
rm -f "$suite_out/positive/generated_optimization.txt"
generated_compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -fopt-info-all="$suite_out/positive/generated_optimization.txt" \
    -c "$suite_out/positive/generated_jvp.f90" \
    -o "$suite_out/positive/generated_jvp.o"
generated_compile_stop=$(date +%s.%N)
generated_compile_seconds=$(awk -v a="$generated_compile_start" \
    -v b="$generated_compile_stop" 'BEGIN {printf "%.6f", b-a}')
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$positive_dir/hand_jvp.f90" -o "$suite_out/positive/hand_jvp.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/harness/bench_callback_select_type.f90" \
    -o "$suite_out/positive/harness.o"
"$fc" "${compile_flags[@]}" -o "$suite_out/positive/bench" \
    "$suite_out/positive/primal.o" \
    "$suite_out/positive/generated_jvp.o" \
    "$suite_out/positive/hand_jvp.o" "$suite_out/positive/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$suite_out/positive/runtime_metrics.txt" \
    "$suite_out/positive/bench" >"$suite_out/positive/run.txt" \
    2>"$suite_out/positive/run.stderr"

source_bytes=$(wc -c <"$suite_out/positive/generated_jvp.f90")
object_bytes=$(stat -c '%s' "$suite_out/positive/generated_jvp.o")
object_text_bytes=$(size -A "$suite_out/positive/generated_jvp.o" | \
    awk '$1 == ".text" {print $2}')
vectorized_loops=$(grep -c 'loop vectorized' \
    "$suite_out/positive/generated_optimization.txt" || true)
optimized_messages=$(grep -c 'optimized:' \
    "$suite_out/positive/generated_optimization.txt" || true)
missed_messages=$(grep -c 'missed:' \
    "$suite_out/positive/generated_optimization.txt" || true)

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: \
    '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= \
    '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)

{
    printf 'suite: itpplasma dynamic callback boundary\n'
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
    printf 'oracle: generated SELECT TYPE JVPs are compared with hand JVPs and fixed values\n'
    printf 'discrete_contract: the callback choice and model coefficients stay passive\n'
    printf '\ncase_id: dynamic-callback-refusal\n'
    printf 'primal_compile_and_run: pass\n'
    printf 'refusal_exit_status: %s\n' "$refusal_status"
    printf 'generated_derivative_present: no\n'
    printf 'diagnostic: %s\n' "$expected_diagnostic"
    printf 'primal_run_output:\n'
    cat "$suite_out/refusal/primal_run.txt"
    printf '\ncase_id: callback-select-type-jvp\n'
    printf 'ad_transform_seconds: %s\n' "$transform_seconds"
    printf 'case_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'generated_object_compile_seconds: %s\n' \
        "$generated_compile_seconds"
    printf 'generated_source_bytes: %s\n' "$source_bytes"
    printf 'generated_object_bytes: %s\n' "$object_bytes"
    printf 'generated_object_text_bytes: %s\n' "$object_text_bytes"
    printf 'generated_vectorized_loop_messages: %s\n' "$vectorized_loops"
    printf 'generated_optimized_messages: %s\n' "$optimized_messages"
    printf 'generated_missed_optimization_messages: %s\n' "$missed_messages"
    cat "$suite_out/positive/runtime_metrics.txt"
    printf 'optimization_report: build/itpplasma-callback-boundary/positive/generated_optimization.txt\n'
    printf 'optimization_diagnostic:\n'
    sed "s#$root/##g" "$suite_out/positive/generated_optimization.txt"
    printf '\nsource_sha256:\n'
    (
        cd "$root"
        sha256sum cases/itpplasma/dynamic_callback_refusal/primal.f90 \
            cases/itpplasma/callback_select_type/primal.f90 \
            cases/itpplasma/callback_select_type/hand_jvp.f90 \
            harness/check_dynamic_callback_primal.f90 \
            harness/bench_callback_select_type.f90 \
            scripts/bench_itpplasma_callback_boundary.sh
    )
    printf 'run_output:\n'
    cat "$suite_out/positive/run.txt"
} >"$result"

cat "$result"
