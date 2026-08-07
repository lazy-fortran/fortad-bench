#!/usr/bin/env bash
# Validate the exact pinned Tapenade set04 tranche B.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
result="$root/results/tapenade_set04_tranche_b_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffree-line-length-none)
normal_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

out=$(mktemp -d /var/tmp/ert/tapenade-set04-tranche-b.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade"

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

compile_capture() {
    local source=$1 object=$2 status_file=$3 flags_name=$4
    local -a flags
    case "$flags_name" in
        strict) flags=("${strict_flags[@]}");;
        normal) flags=("${normal_flags[@]}" "-J$out/mod" "-I$out/mod");;
        *) printf 'unknown compiler flag set %s\n' "$flags_name" >&2; return 2;;
    esac
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
}

case_dir="$tapenade_repo/nonRegressions/set04"
declare -A proc=(
    [lh128]=test
    [lh151]=MUL
    [lh152]=SATVAP
)
declare -A indep=(
    [lh128]=w
    [lh151]=A,B
    [lh152]=temp2
)
declare -A dep=(
    [lh128]=w
    [lh151]=C
    [lh152]=eval
)

for case_id in lh128 lh151 lh152; do
    source="$case_dir/$case_id/program.f90"
    compile_capture "$source" "$out/$case_id-upstream.o" "$out/$case_id-upstream.status" strict
    test "$(cat "$out/$case_id-upstream.status")" = 0
done

for case_id in lh128 lh151 lh152; do
    case_out="$out/tapenade/$case_id"
    mkdir -p "$case_out/parser" "$case_out/forward" "$case_out/reverse"
    source="$case_dir/$case_id/program.f90"
    "$tapenade" -p -root "${proc[$case_id]}" -O "$case_out/parser" -o "${case_id}_p" "$source" \
        >"$case_out/parser.stdout" 2>"$case_out/parser.stderr"
    "$tapenade" -d -root "${proc[$case_id]}" -O "$case_out/forward" -o "${case_id}_d" "$source" \
        >"$case_out/forward.stdout" 2>"$case_out/forward.stderr"
    "$tapenade" -b -root "${proc[$case_id]}" -O "$case_out/reverse" -o "${case_id}_b" "$source" \
        >"$case_out/reverse.stdout" 2>"$case_out/reverse.stderr"
    for mode in parser forward reverse; do
        generated=$(find "$case_out/$mode" -maxdepth 1 -type f -name '*.f90' -print -quit)
        test -n "$generated"
        compile_capture "$generated" "$case_out/$mode-generated.o" \
            "$case_out/$mode-generated-strict.status" strict
        test "$(cat "$case_out/$mode-generated-strict.status")" = 0
    done
done

fortad_exec() { (cd "$fortad_repo" && fo exec --no-build fortad "$@"); }

for case_id in lh128 lh151 lh152; do
    source="$case_dir/$case_id/program.f90"
    fortad_exec jvp "${indep[$case_id]}" --proc "${proc[$case_id]}" \
        --name "set04_${case_id}_jvp" --module "set04_${case_id}_jvp_mod" \
        --output "$out/$case_id-jvp.f90" "$source" \
        >"$out/$case_id-jvp.stdout" 2>"$out/$case_id-jvp.stderr"
    test -s "$out/$case_id-jvp.f90"
done

set +e
fortad_exec vjp "${indep[lh128]}" --dep "${dep[lh128]}" --proc "${proc[lh128]}" \
    --name set04_lh128_vjp --module set04_lh128_vjp_mod \
    --output "$out/lh128-vjp.f90" "$case_dir/lh128/program.f90" \
    >"$out/lh128-vjp.stdout" 2>"$out/lh128-vjp.stderr"
lh128_vjp_transform_status=$?
set -e
test "$lh128_vjp_transform_status" = 0
test -s "$out/lh128-vjp.f90"

set +e
fortad_exec vjp "${indep[lh151]}" --dep "${dep[lh151]}" --proc "${proc[lh151]}" \
    --name set04_lh151_vjp --module set04_lh151_vjp_mod \
    --output "$out/lh151-vjp.f90" "$case_dir/lh151/program.f90" \
    >"$out/lh151-vjp.stdout" 2>"$out/lh151-vjp.stderr"
lh151_vjp_transform_status=$?
set -e
test "$lh151_vjp_transform_status" = 1
grep -Fq 'fortad: reverse mode: this loop accumulates nothing, writes no array element, and carries nothing across iterations' \
    "$out/lh151-vjp.stderr"
test ! -e "$out/lh151-vjp.f90"

for case_id in lh152; do
    source="$case_dir/$case_id/program.f90"
    fortad_exec vjp "${indep[$case_id]}" --dep "${dep[$case_id]}" --proc "${proc[$case_id]}" \
        --name "set04_${case_id}_vjp" --module "set04_${case_id}_vjp_mod" \
        --output "$out/$case_id-vjp.f90" "$source" \
        >"$out/$case_id-vjp.stdout" 2>"$out/$case_id-vjp.stderr"
    test -s "$out/$case_id-vjp.f90"
done

for case_id in lh128 lh151 lh152; do
    compile_capture "$out/$case_id-jvp.f90" "$out/$case_id-jvp.o" \
        "$out/$case_id-jvp.status" normal
    test "$(cat "$out/$case_id-jvp.status")" = 0
done
for case_id in lh152; do
    compile_capture "$out/$case_id-vjp.f90" "$out/$case_id-vjp.o" \
        "$out/$case_id-vjp.status" normal
    test "$(cat "$out/$case_id-vjp.status")" = 0
done

compile_capture "$out/lh128-vjp.f90" "$out/lh128-vjp-generated.o" \
    "$out/lh128-vjp-generated.status" normal
test "$(cat "$out/lh128-vjp-generated.status")" -ne 0
grep -Eiq 'duplicate symbol.*w_b|w_b.*duplicate symbol' "$out/lh128-vjp-generated.o.stderr"

compile_capture "$root/harness/bench_tapenade_set04_tranche_b.f90" \
    "$out/harness.o" "$out/harness.status" normal
test "$(cat "$out/harness.status")" = 0

"$fc" "${normal_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh128-upstream.o" "$out/lh128-jvp.o" \
    "$out/lh151-upstream.o" "$out/lh151-jvp.o" \
    "$out/lh152-upstream.o" "$out/lh152-jvp.o" "$out/lh152-vjp.o" \
    "$out/harness.o"

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'suite: Tapenade nonRegressions set04 tranche B (lh128, lh151, lh152)\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict_flags[*]}"
    printf 'normal_flags: %s\n' "${normal_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_source_compile_statuses:\n'
    for case_id in lh128 lh151 lh152; do
        printf '%s %s\n' "$case_id" "$(cat "$out/$case_id-upstream.status")"
    done
    printf 'tapenade_generation: fresh parser, tangent, and reverse outputs generated for all three exact sources\n'
    printf 'tapenade_generated_strict_statuses:\n'
    find "$out/tapenade" -name '*-generated-strict.status' -print | sort | while read -r status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'fortad_lh128_forward: transform=0 compile=0\n'
    printf 'fortad_lh128_reverse: transform=%s generated_compile=%s diagnostic=duplicate-w_b\n' \
        "$lh128_vjp_transform_status" "$(cat "$out/lh128-vjp-generated.status")"
    printf 'fortad_lh151_forward: transform=0 compile=0\n'
    printf 'fortad_lh151_reverse: transform=%s diagnostic=stable-loop-refusal\n' "$lh151_vjp_transform_status"
    printf 'fortad_lh152_forward_reverse: transform=0 compile=0\n'
    printf 'independent_oracle: central-difference JVPs, hand complex JVP, and scalar reverse adjoint\n'
    cat "$out/runtime-metrics.txt"
    cat "$out/run.txt"
    printf 'oracle_status: pass\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        nonRegressions/set04/lh128/program.f90 nonRegressions/set04/lh128/program_b.f90 \
        nonRegressions/set04/lh128/program_b.msg \
        nonRegressions/set04/lh151/program.f90 nonRegressions/set04/lh151/program_b.f90 \
        nonRegressions/set04/lh151/program_b.msg \
        nonRegressions/set04/lh152/program.f90 nonRegressions/set04/lh152/program_b.f90 \
        nonRegressions/set04/lh152/program_b.msg)
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set04/tranche-b-manifest.toml \
        cases/tapenade-set04/tranche-b.md \
        harness/bench_tapenade_set04_tranche_b.f90 \
        scripts/bench_tapenade_set04_tranche_b.sh)
} >"$result"
cat "$result"
