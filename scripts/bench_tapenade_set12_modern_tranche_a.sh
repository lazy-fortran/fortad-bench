#!/usr/bin/env bash
# Fresh Tapenade/FortAD probes for the set12 modern complex/polymorphism tranche.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
fc=${FC:-gfortran}
required_tapenade=e59864cab441d4175df75383b3ff58c3dcd26df9
required_fortad=b7533af9c4d22eae92b278d2f0200127061f00a9
result="$root/results/tapenade_set12_modern_tranche_a_validation.txt"
build=$(mktemp -d "$root/build/tapenade-set12-modern-a.XXXXXX")

command -v "$fc" >/dev/null
command -v fo >/dev/null
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade_repo/bin/tapenade"

compile_source() {
    local source=$1
    shift
    set +e
    "$fc" "$@" -fsyntax-only "$source" >"$build/$(basename "$source").stdout" \
        2>"$build/$(basename "$source").stderr"
    local status=$?
    set -e
    printf '%s\n' "$status"
}

run_tapenade_case() {
    local id=$1
    local root_name=$2
    local source="$tapenade_repo/nonRegressions/set12/$id/program.f90"
    local case_out="$build/tapenade/$id"
    mkdir -p "$case_out/parser" "$case_out/forward" "$case_out/reverse"
    local source_status
    if test "$id" = cmplxstep01; then
        source_status=$(compile_source "$source" -std=legacy -ffree-line-length-none)
    else
        source_status=$(compile_source "$source" -std=f2018 -ffree-line-length-none)
    fi
    printf '%s source %s\n' "$id" "$source_status" >>"$build/tapenade-statuses"
    for mode in parser forward reverse; do
        local flag
        case "$mode" in
            parser) flag=p;;
            forward) flag=d;;
            reverse) flag=b;;
        esac
        set +e
        (cd "$(dirname "$source")" && "$tapenade_repo/bin/tapenade" \
            -"$flag" -root "$root_name" -O "$case_out/$mode" program.f90) \
            >"$case_out/$mode.stdout" 2>"$case_out/$mode.stderr"
        local status=$?
        set -e
        test "$status" -eq 0
        local generated="$case_out/$mode/program_${flag}.f90"
        local generated_status
        if test -s "$generated"; then
            if test "$id" = cmplxstep01; then
                generated_status=$(compile_source "$generated" -std=legacy -ffree-line-length-none)
            else
                generated_status=$(compile_source "$generated" -std=f2018 -ffree-line-length-none)
            fi
        else
            generated_status=missing
        fi
        printf '%s %s %s %s\n' "$id" "$mode" "$status" "$generated_status" >>"$build/tapenade-statuses"
    done
}

run_fortad_case() {
    local id=$1
    local proc=$2
    local indep=$3
    local dep=$4
    local source="$tapenade_repo/nonRegressions/set12/$id/program.f90"
    local case_out="$build/fortad/$id"
    mkdir -p "$case_out"
    for mode in forward reverse; do
        local generated="$case_out/${mode}.f90"
        set +e
        (cd "$fortad_repo" && fo exec --no-build fortad --mode "$mode" \
            --indep "$indep" --dep "$dep" --proc "$proc" \
            --name "set12_${id}_${mode}" --module "set12_${id}_${mode}_ad" \
            --output "$generated" "$source") \
            >"$case_out/${mode}.stdout" 2>"$case_out/${mode}.stderr"
        local status=$?
        set -e
        test "$status" -ne 0
        printf '%s %s %s\n' "$id" "$mode" "$status" >>"$build/fortad-statuses"
    done
}

mkdir -p "$build/tapenade" "$build/fortad"
for spec in \
    "cmplxstep01 ff1 a,b ff1" \
    "f03typf01 foo x y" \
    "f03fptr01 foo x y"; do
    set -- $spec
    run_tapenade_case "$1" "$2"
    run_fortad_case "$1" "$2" "$3" "$4"
done

if test -z "${FORTAD_SKIP_BUILD:-}"; then
    (cd "$fortad_repo" && fo build) >"$build/fortad-build.log" 2>&1
fi
"$fc" -std=f2018 -pedantic-errors -ffree-line-length-none -O2 \
    -o "$build/oracle" "$root/harness/bench_tapenade_set12_modern_tranche_a.f90"
"$build/oracle" >"$build/oracle.txt"
grep -Fqx 'oracle_status: pass' "$build/oracle.txt"

{
    printf 'tranche: Tapenade set12 modern tranche A\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'exact_source_compile_flags: cmplxstep01=-std=legacy -ffree-line-length-none; other cases=-std=f2018 -ffree-line-length-none\n'
    printf 'tapenade_oracle: fresh parser, forward, and reverse generation; generated source compile status is recorded below\n'
    printf 'tapenade_generated_compile_statuses:\n'
    sort "$build/tapenade-statuses"
    printf 'fortad_oracle: both requested modes refuse the active boundary; stderr is retained in the run build directory\n'
    printf 'fortad_statuses:\n'
    sort "$build/fortad-statuses"
    printf 'independent_oracle: hand primal/JVP/VJP formulas for pure quadratic, deferred child dispatch, and procedure-pointer selection\n'
    cat "$build/oracle.txt"
    printf 'classification:\n'
    printf 'cmplxstep01 expected-refusal (active mutable module state)\n'
    printf 'f03typf01 expected-refusal (abstract deferred type-bound dispatch)\n'
    printf 'f03fptr01 expected-refusal (abstract procedure interface and procedure pointer)\n'
    printf 'exact_source_sha256:\n'
    sha256sum \
        "$tapenade_repo/nonRegressions/set12/cmplxstep01/program.f90" \
        "$tapenade_repo/nonRegressions/set12/f03typf01/program.f90" \
        "$tapenade_repo/nonRegressions/set12/f03fptr01/program.f90"
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set12/modern-tranche-a-manifest.toml \
        cases/tapenade-set12/modern-tranche-a.md \
        harness/bench_tapenade_set12_modern_tranche_a.f90 \
        scripts/bench_tapenade_set12_modern_tranche_a.sh \
        scripts/test_tapenade_set12_modern_tranche_a.py)
} >"$result"
cat "$result"
