#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
result="$root/results/tapenade_set05_shard3_v125_v137_validation.txt"
if test -x "$root/../fortad/build/fo/bin/fortad"; then
    fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
else
    fortad_repo=${FORTAD_REPO:-"$root/../../code/lazy-fortran/fortad"}
fi
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fc=${FC:-gfortran}
fortad=${FORTAD_CLI:-"$fortad_repo/build/fo/bin/fortad"}
tapenade="$tapenade_repo/bin/tapenade"
required_fortad_commit=10e6846573a8a4f172f557dbb20169ee73bcbbd5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
strict_flags=(-std=f2018 -pedantic-errors -ffree-line-length-none)
normal_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

test -x "$fortad"
test -x "$tapenade"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"

out=$(mktemp -d /var/tmp/ert/tapenade-set05-shard3-v125-v137.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade"

compile_strict() {
    local source=$1 object=$2
    "$fc" "${strict_flags[@]}" -c "$source" -o "$object"
}

compile_normal() {
    local source=$1 object=$2
    "$fc" "${normal_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" -o "$object"
}

generate_tapenade() {
    local id=$1 root_name=$2
    local source="$tapenade_repo/nonRegressions/set05/$id/program.f90"
    local case_out="$out/tapenade/$id"
    compile_strict "$source" "$out/upstream-$id.o"
    for mode in p d b; do
        local mode_dir="$case_out/$mode"
        mkdir -p "$mode_dir"
        "$tapenade" "-$mode" -root "$root_name" -O "$mode_dir" -o "${id}_${mode}" "$source" \
            >"$case_out/${mode}.stdout" 2>"$case_out/${mode}.stderr"
        local found=0
        for generated in "$mode_dir"/*.f90; do
            test -f "$generated"
            found=1
            compile_strict "$generated" "$generated.o"
        done
        test "$found" = 1
    done
}

generate_tapenade v125 surface
generate_tapenade v137 s

for spec in \
    "v125 set05_v125 x1,x2,y1,y2 z" \
    "v137 set05_v137 x,y s"; do
    set -- $spec
    id=$1; proc=$2; indep=$3; dep=$4
    source="$root/cases/tapenade-set05-shard3-v125-v137/$id.f90"
    compile_normal "$source" "$out/$id-port.o"
    "$fortad" jvp "$indep" --dep "$dep" --proc "$proc" \
        --name "${proc}_jvp" --module "${proc}_jvp_mod" \
        --output "$out/${id}_jvp.f90" "$source" \
        >"$out/${id}-fortad-jvp.log" 2>&1
    "$fortad" vjp "$indep" --dep "$dep" --proc "$proc" \
        --name "${proc}_vjp" --module "${proc}_vjp_mod" \
        --output "$out/${id}_vjp.f90" "$source" \
        >"$out/${id}-fortad-vjp.log" 2>&1
    compile_normal "$out/${id}_jvp.f90" "$out/${id}_jvp.o"
    compile_normal "$out/${id}_vjp.f90" "$out/${id}_vjp.o"
done

compile_normal "$root/harness/bench_tapenade_set05_shard3_v125_v137.f90" "$out/harness.o"
"$fc" "${normal_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/v125-port.o" "$out/v125_jvp.o" "$out/v125_vjp.o" \
    "$out/v137-port.o" "$out/v137_jvp.o" "$out/v137_vjp.o" "$out/harness.o"

python3 "$root/cases/tapenade-set05-shard3-v125-v137/test_oracle.py" >"$out/python-oracle.txt"
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'suite: Tapenade nonRegressions set05/v125 set05/v137\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${normal_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'tapenade_gate: fresh parser, forward, and reverse products generated from exact upstream sources; all generated sources compile strictly\n'
    printf 'fortad_gate: JVP and VJP generated from standards-clean ports; all generated sources compile\n'
    printf 'independent_oracle: hand derivatives, central finite differences, and adjoint identities\n'
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set05-shard3-v125-v137/v125.f90 \
        cases/tapenade-set05-shard3-v125-v137/v137.f90 \
        cases/tapenade-set05-shard3-v125-v137/oracle.py \
        cases/tapenade-set05-shard3-v125-v137/manifest.toml \
        cases/tapenade-set05-shard3-v125-v137/README.md \
        harness/bench_tapenade_set05_shard3_v125_v137.f90 \
        scripts/bench_tapenade_set05_shard3_v125_v137.sh)
    cat "$out/runtime-metrics.txt"
    printf 'python_oracle:\n'
    cat "$out/python-oracle.txt"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
