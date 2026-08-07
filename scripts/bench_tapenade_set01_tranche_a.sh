#!/usr/bin/env bash
# Validate lh088 support and the exact lh066 reverse refusal boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_tranche_a_validation.txt"
refusal_result="$root/results/tapenade_set01_refusals.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=571c86da9516739653a558fabbd8277e796caec8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v python3 >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
if ! git -C "$fortad_repo" merge-base --is-ancestor \
    "$required_fortad_commit" HEAD; then
    printf 'FortAD HEAD must contain %s\n' "$required_fortad_commit" >&2
    exit 1
fi
if test -n "$(git -C "$fortad_repo" status --porcelain \
    --untracked-files=no)"; then
    printf 'FortAD checkout has tracked changes; refusing an ambiguous run\n' >&2
    exit 1
fi
if test "$(git -C "$tapenade_repo" rev-parse HEAD)" != \
    "$required_tapenade_commit"; then
    printf 'Tapenade checkout must be pinned at %s\n' \
        "$required_tapenade_commit" >&2
    exit 1
fi
if test -n "$(git -C "$tapenade_repo" status --porcelain \
    --untracked-files=no)"; then
    printf 'Tapenade checkout has tracked changes; refusing an ambiguous run\n' >&2
    exit 1
fi

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-tranche-a.XXXXXX")
mkdir -p "$out/mod"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

forward_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep 'a,b,c,d' \
        --proc set01_lh088 --name set01_lh088_jvp \
        --module set01_lh088_ad --output "$out/lh088_jvp.f90" \
        "$case_dir/lh088.f90"
) >"$out/lh088_forward.stdout" 2>"$out/lh088_forward.stderr"
forward_stop=$(date +%s.%N)
forward_seconds=$(awk -v a="$forward_start" -v b="$forward_stop" \
    'BEGIN {printf "%.6f", b-a}')

reverse_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode reverse --indep 'a,b,c,d' \
        --dep total --proc set01_lh088 --name set01_lh088_vjp \
        --module set01_lh088_reverse_ad --output "$out/lh088_vjp.f90" \
        "$case_dir/lh088.f90"
) >"$out/lh088_reverse.stdout" 2>"$out/lh088_reverse.stderr"
reverse_stop=$(date +%s.%N)
reverse_seconds=$(awk -v a="$reverse_start" -v b="$reverse_stop" \
    'BEGIN {printf "%.6f", b-a}')

"$fc" -std=f2018 -pedantic-errors -c \
    "$tapenade_repo/nonRegressions/set01/lh088/program.f" \
    -o "$out/lh088_upstream.o"
compile_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$case_dir/lh088.f90" -o "$out/lh088_primal.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$case_dir/hand_derivatives_lh088.f90" -o "$out/lh088_hand.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$out/lh088_jvp.f90" -o "$out/lh088_jvp.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$out/lh088_vjp.f90" -o "$out/lh088_vjp.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$root/harness/bench_tapenade_set01_tranche_a.f90" \
    -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/bench" \
    "$out/lh088_primal.o" "$out/lh088_hand.o" "$out/lh088_jvp.o" \
    "$out/lh088_vjp.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')
"$out/bench" >"$out/run.txt"
grep -Fq 'oracle_status: pass' "$out/run.txt"

# Keep the exact in-place upstream shape as a refusal regression.  FortAD's
# reverse emitter currently produces two a_b dummies; gfortran is the oracle
# that must reject that generated source.
set +e
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode reverse --indep 'a,b' --dep a \
        --proc set01_lh066_refusal --name set01_lh066_refusal_vjp \
        --module set01_lh066_refusal_reverse_ad \
        --output "$out/lh066_refusal_vjp.f90" \
        "$case_dir/lh066_refusal.f90"
) >"$out/lh066_refusal_transform.stdout" \
    2>"$out/lh066_refusal_transform.stderr"
refusal_transform_status=$?
if test "$refusal_transform_status" -eq 0; then
    "$fc" -std=f2018 -pedantic-errors -c "$out/lh066_refusal_vjp.f90" \
        -o "$out/lh066_refusal.o" \
        >"$out/lh066_refusal_compile.stdout" \
        2>"$out/lh066_refusal_compile.stderr"
    refusal_compile_status=$?
else
    refusal_compile_status=not-attempted
fi
set -e
test "$refusal_transform_status" -eq 0
test "$refusal_compile_status" != 0
grep -Fq 'Duplicate symbol' "$out/lh066_refusal_compile.stderr"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'suite: Tapenade nonRegressions set01 tranche A (lh088 plus lh066 refusal)\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_setup_seconds_cached_or_incremental: %s\n' "$setup_seconds"
    printf 'lh088_jvp_transform_seconds: %s\n' "$forward_seconds"
    printf 'lh088_vjp_transform_seconds: %s\n' "$reverse_seconds"
    printf 'lh088_generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'oracle: hand JVP/VJP, four-step central differences, adjoint identity\n'
    printf 'upstream_compiler_oracle: lh088 unmodified fixed-form source compiles with -std=f2018 -pedantic-errors\n'
    printf 'tapenade_result: stored program_d/program_b references present; current Tapenade executable not rerun\n'
    printf 'source_sha256:\n'
    (
        cd "$root"
        sha256sum cases/tapenade-set01/lh088.f90 \
            cases/tapenade-set01/hand_derivatives_lh088.f90 \
            cases/tapenade-set01/lh066_refusal.f90 \
            harness/bench_tapenade_set01_tranche_a.f90 \
            scripts/bench_tapenade_set01_tranche_a.sh
    )
    printf 'generated_source_sha256:\n'
    sha256sum "$out/lh088_jvp.f90" "$out/lh088_vjp.f90" | sed "s#$out/##"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

{
    printf 'suite: Tapenade set01 exact-source refusal regression\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'case: lh066\n'
    printf 'upstream_source: nonRegressions/set01/lh066/program.f\n'
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'attempted_command: fo exec --no-build fortad --mode reverse --indep a,b --dep a --proc set01_lh066_refusal\n'
    printf 'transform_exit_status: %s\n' "$refusal_transform_status"
    printf 'generated_source_compile_exit_status: %s\n' "$refusal_compile_status"
    printf 'oracle: gfortran -std=f2018 -pedantic-errors rejects duplicate a_b dummy\n'
    printf 'diagnostic:\n'
    sed "s#$out/#<build>/#g" "$out/lh066_refusal_compile.stderr"
    printf 'status: expected-refusal\n'
} >"$refusal_result"

cat "$result"
cat "$refusal_result"
