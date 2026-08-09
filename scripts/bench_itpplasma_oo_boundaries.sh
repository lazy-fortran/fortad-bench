#!/usr/bin/env bash
# Validate advanced OO primals and record explicit FortAD refusal boundaries.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
suite_out="$root/build/itpplasma-oo-boundaries"
mod_dir="$suite_out/mod"
result="$root/results/itpplasma_oo_boundaries_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
required_fortad_commit=cc8987edbfcdc15b8a263473a651a4843c79a46e
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
if ! git -C "$fortad_repo" merge-base --is-ancestor \
    "$required_fortad_commit" HEAD; then
    printf 'FortAD HEAD must contain %s\n' "$required_fortad_commit" >&2
    exit 1
fi

mkdir -p "$mod_dir" "$suite_out/abstract" "$suite_out/ownership" \
    "$suite_out/callback" "$root/results"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$suite_out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

abstract_dir="$root/cases/itpplasma/abstract_deferred_refusal"
ownership_dir="$root/cases/itpplasma/polymorphic_ownership_refusal"
callback_dir="$root/cases/itpplasma/callback_context_refusal"

compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$abstract_dir/primal.f90" -o "$suite_out/abstract/primal.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$ownership_dir/primal.f90" -o "$suite_out/ownership/primal.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$callback_dir/primal.f90" -o "$suite_out/callback/primal.o"
"$fc" "${compile_flags[@]}" -J"$mod_dir" -I"$mod_dir" \
    -c "$root/harness/check_oo_boundaries.f90" \
    -o "$suite_out/harness.o"
"$fc" "${compile_flags[@]}" -o "$suite_out/check" \
    "$suite_out/abstract/primal.o" "$suite_out/ownership/primal.o" \
    "$suite_out/callback/primal.o" "$suite_out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

"$suite_out/check" >"$suite_out/primal_run.txt"
grep -Fqx 'PASS: abstract deferred, ownership, and callback primal oracles' \
    "$suite_out/primal_run.txt"

run_refusal() {
    local id=$1 proc=$2 module=$3 expected=$4
    local case_out="$suite_out/$id"
    local source
    local output="$case_out/generated_jvp.f90"
    local status

    # The three case directory names do not all share the suffix used by id.
    case "$id" in
        abstract) source="$abstract_dir/primal.f90" ;;
        ownership) source="$ownership_dir/primal.f90" ;;
        callback) source="$callback_dir/primal.f90" ;;
    esac

    # A previous accepted run must not make a later refusal look like it
    # emitted derivative code.  The output path is fixed to this case's
    # private build directory above.
    rm -f "$output"
    set +e
    (
        cd "$fortad_repo"
        fo exec --no-build fortad --mode forward --indep x \
            --proc "$proc" --name "${proc}_jvp" --module "$module" \
            --output "$output" "$source"
    ) >"$case_out/transform.stdout" 2>"$case_out/transform.stderr"
    status=$?
    set -e

    test "$status" -ne 0
    grep -Fq "$expected" "$case_out/transform.stderr"
    test ! -e "$output"
    printf '%s\n' "$status" >"$case_out/refusal_status"
    printf '%s\n' "$expected" >"$case_out/expected_diagnostic"
}

run_refusal abstract evaluate_deferred deferred_ad \
    "fortad: unsupported type-bound call 'value': direct polymorphic dispatch requires one FortFront-proven concrete runtime target; multiple runtime targets are unsupported"
run_refusal ownership evaluate_owned ownership_ad \
    "fortad: unsupported type-bound call 'value': polymorphic component receiver ownership or dynamic type is unsupported"
run_refusal callback evaluate_callback callback_ad \
    "fortad: module-level allocatable mutable state is not supported; use local or dummy ownership"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: \
    '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= \
    '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)

{
    printf 'suite: itpplasma advanced OO/interface refusal boundaries\n'
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
    printf 'primal_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'oracle: fixed values and central finite differences for each child/callback target; null callback value checked\n'
    printf 'discrete_contract: dynamic type, ownership transition, callback target, and callback context are passive choices\n'
    printf '\ncase_id: abstract-deferred-binding\n'
    printf 'status: expected-refusal\n'
    printf 'primal_oracle: pass\n'
    printf 'refusal_exit_status: %s\n' "$(cat "$suite_out/abstract/refusal_status")"
    printf 'diagnostic: %s\n' "$(cat "$suite_out/abstract/expected_diagnostic")"
    printf '\ncase_id: polymorphic-ownership\n'
    printf 'status: expected-refusal\n'
    printf 'primal_oracle: pass\n'
    printf 'refusal_exit_status: %s\n' "$(cat "$suite_out/ownership/refusal_status")"
    printf 'diagnostic: %s\n' "$(cat "$suite_out/ownership/expected_diagnostic")"
    printf '\ncase_id: callback-class-star-context\n'
    printf 'status: expected-refusal\n'
    printf 'primal_oracle: pass\n'
    printf 'refusal_exit_status: %s\n' "$(cat "$suite_out/callback/refusal_status")"
    printf 'diagnostic: %s\n' "$(cat "$suite_out/callback/expected_diagnostic")"
    printf '\nsource_sha256:\n'
    (
        cd "$root"
        sha256sum cases/itpplasma/abstract_deferred_refusal/primal.f90 \
            cases/itpplasma/polymorphic_ownership_refusal/primal.f90 \
            cases/itpplasma/callback_context_refusal/primal.f90 \
            harness/check_oo_boundaries.f90 \
            scripts/bench_itpplasma_oo_boundaries.sh
    )
    printf 'primal_run_output:\n'
    cat "$suite_out/primal_run.txt"
} >"$result"

cat "$result"
