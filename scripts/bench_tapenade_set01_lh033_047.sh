#!/usr/bin/env bash
# Validate the pinned Tapenade set01 lh033/lh039/lh040 boundary tranche.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh033_047_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
if ! test -d "$fortad_repo/.git" && ! test -f "$fortad_repo/.git" && \
   test -d /mnt/storage/code/lazy-fortran/fortad/.git; then
    fortad_repo=/mnt/storage/code/lazy-fortran/fortad
fi
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=90e9b9b15941f4e4f2f8d75a0a74a20650f69e9b
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)
upstream_dir="$tapenade_repo/nonRegressions/set01"

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

for case_id in lh033 lh039 lh040; do
    test -s "$upstream_dir/$case_id/program.f"
done
mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh033-047.XXXXXX")
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/mod"

upstream_start=$(date +%s.%N)
for case_id in lh033 lh039 lh040; do
    "$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c \
        "$upstream_dir/$case_id/program.f" -o "$out/upstream-$case_id.o"
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

tap_start=$(date +%s.%N)
for case_id in lh033 lh039 lh040; do
    case "$case_id" in lh033) head=absorbN;; lh039) head=top;; lh040) head=f;; esac
    for mode in p d b; do
        case "$mode" in
            p) dest="$out/tapenade/parser";;
            d) dest="$out/tapenade/forward";;
            b) dest="$out/tapenade/reverse";;
        esac
        "$tapenade_repo/bin/tapenade" -"$mode" -head "$head" -O "$dest" \
            -o "$case_id" "$upstream_dir/$case_id/program.f" \
            >"$out/tapenade-$case_id-$mode.stdout" \
            2>"$out/tapenade-$case_id-$mode.stderr"
    done
done
tap_stop=$(date +%s.%N)
tap_seconds=$(awk -v a="$tap_start" -v b="$tap_stop" \
    'BEGIN {printf "%.6f", b-a}')

for generated in \
    "$out/tapenade/parser/lh033_p.f" "$out/tapenade/forward/lh033_d.f" \
    "$out/tapenade/reverse/lh033_b.f" "$out/tapenade/parser/lh039_p.f" \
    "$out/tapenade/forward/lh039_d.f" "$out/tapenade/reverse/lh039_b.f" \
    "$out/tapenade/parser/lh040_p.f" "$out/tapenade/forward/lh040_d.f" \
    "$out/tapenade/reverse/lh040_b.f"; do
    test -s "$generated"
    "$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c "$generated" \
        -o "$out/$(basename "$generated").o"
done

refusal_start=$(date +%s.%N)
for spec in "lh033 absorbN data resu 5" "lh040 f t f 4"; do
    read -r case_id proc indep dep line <<<"$spec"
    for mode in forward reverse; do
        if (cd "$fortad_repo" && fo exec --no-build fortad --mode "$mode" \
            --indep "$indep" --dep "$dep" --proc "$proc" \
            --name "${case_id}_${mode}_refusal" \
            --module "${case_id}_${mode}_refusal_mod" \
            --output "$out/${case_id}_${mode}.f90" \
            "$upstream_dir/$case_id/program.f") \
            >"$out/fortad-$case_id-$mode.stdout" \
            2>"$out/fortad-$case_id-$mode.stderr"; then
            echo "FortAD unexpectedly accepted $case_id $mode" >&2
            exit 1
        fi
        grep -Fqx "fortad: unsupported statement at line $line" \
            "$out/fortad-$case_id-$mode.stderr"
    done
done
refusal_stop=$(date +%s.%N)
refusal_seconds=$(awk -v a="$refusal_start" -v b="$refusal_stop" \
    'BEGIN {printf "%.6f", b-a}')

fortad_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
    --indep i1,i2,i3 --proc set01_lh039 --name lh039_jvp \
    --module lh039_jvp_mod --output "$out/lh039_forward.f90" \
    "$case_dir/lh039.f90") >"$out/fortad-lh039-forward.stdout" \
    2>"$out/fortad-lh039-forward.stderr"
(cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
    --indep i1,i2,i3 --dep o1 --proc set01_lh039 --name lh039_vjp \
    --module lh039_vjp_mod --output "$out/lh039_reverse.f90" \
    "$case_dir/lh039.f90") >"$out/fortad-lh039-reverse.stdout" \
    2>"$out/fortad-lh039-reverse.stderr"
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
for source in "$case_dir/lh039.f90" \
    "$case_dir/hand_derivatives_lh033_040.f90" \
    "$out/lh039_forward.f90" "$out/lh039_reverse.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$base.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_lh033_047.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/bench" \
    "$out/upstream-lh033.o" "$out/lh039.o" "$out/upstream-lh040.o" \
    "$out/lh039_forward.o" "$out/lh039_reverse.o" \
    "$out/hand_derivatives_lh033_040.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh033 lh039 lh040\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'tapenade_fresh_generation_seconds: %s\n' "$tap_seconds"
    printf 'tapenade_generated_compile: pass-strict\n'
    printf 'fortad_refusal_probe_seconds: %s\n' "$refusal_seconds"
    printf 'fortad_positive_transform_seconds: %s\n' "$fortad_seconds"
    printf 'fortad_generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'tapenade_oracle: fresh parser, tangent, and reverse outputs for all three exact sources compile under strict fixed-form mode\n'
    printf 'fortad_oracle: lh039 forward and reverse transform compile and run; lh033/lh040 exact-source refusals retain line diagnostics\n'
    printf 'oracle: independent hand JVP, central-difference sweeps, and VJP adjoint identity\n'
    cat "$out/runtime-metrics.txt"
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh039.f90 \
        cases/tapenade-set01/hand_derivatives_lh033_040.f90 \
        cases/tapenade-set01/tranche-m-lh033-047-manifest.toml \
        cases/tapenade-set01/tranche-m-lh033-047.md \
        harness/bench_tapenade_set01_lh033_047.f90 \
        scripts/bench_tapenade_set01_lh033_047.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
