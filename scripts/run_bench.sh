#!/usr/bin/env bash
# Run the dot_sin comparison end to end: generate fortad code, build the
# Enzyme baseline, compile everything with the same compiler, run, and record
# both runtime and the build time each engine cost.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
case_dir=cases/dot_sin
out=build/dot_sin
fc=${FC:-flang}

mkdir -p "$out" results

echo "== generating fortad derivative code"
fortad_bin="$fortad_repo/build/fortad-bin"
if [ ! -x "$fortad_bin" ]; then
    ( cd "$fortad_repo" && fpm build >/dev/null 2>&1 )
    fortad_bin=$(find "$fortad_repo/build" -name fortad -type f -perm -u+x | head -1)
fi

t0=$(date +%s.%N)
"$fortad_bin" --indep a,b --name dot_sin_jvp \
    -o "$out/fortad_scalar.f90" "$case_dir/primal_plain.f90"
"$fortad_bin" --indep a,b --name dot_sin_jvp_v -d nd \
    -o "$out/fortad_vector.f90" "$case_dir/primal_plain.f90"
t1=$(date +%s.%N)
gen_time=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')

echo "== building Enzyme baseline"
t0=$(date +%s.%N)
./scripts/build_enzyme.sh "$case_dir" "$out"
t1=$(date +%s.%N)
enzyme_build=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')

echo "== compiling"
t0=$(date +%s.%N)
$fc -O3 -c "$case_dir/analytical.f90" -o "$out/analytical.o"
$fc -O3 -c "$out/fortad_scalar.f90" -o "$out/fortad_scalar.o"
$fc -O3 -c "$out/fortad_vector.f90" -o "$out/fortad_vector.o"
t1=$(date +%s.%N)
fortad_compile=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')

# enzyme.o already contains the primal kernel, because Enzyme differentiates
# the linked IR of kernel plus wrapper. Linking kernel.o as well would define
# dot_sin twice.
$fc -O3 -o "$out/bench" harness/bench_dot_sin.f90 \
    "$out/analytical.o" "$out/fortad_scalar.o" "$out/fortad_vector.o" \
    "$out/enzyme.o"

echo "== running"
"$out/bench"

{
    echo "stage,seconds"
    echo "fortad_generate,$gen_time"
    echo "fortad_compile,$fortad_compile"
    echo "enzyme_build,$enzyme_build"
} > results/dot_sin_build.csv
echo "wrote results/dot_sin_build.csv"
cat results/dot_sin_build.csv
