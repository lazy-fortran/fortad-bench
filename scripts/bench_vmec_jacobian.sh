#!/usr/bin/env bash
# Build and run the hand-written VMEC++ half-grid Jacobian port.
# Run this on a TU Graz host; it is intentionally not a workstation fallback.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

fc=${FC:-gfortran}
time_cmd=${TIME_CMD:-/usr/bin/time}
out=${OUT:-build/vmec-jacobian}
mkdir -p "$out"
test -x "$(command -v "$fc")"
test -x "$time_cmd"

t0=$(date +%s.%N)
"$fc" -O3 -ffree-line-length-none -Wall -Wextra -std=f2008 \
  -fopt-info-vec-all="$out/vectorization.txt" \
  -c cases/vmec-jacobian/kernel.f90 -o "$out/kernel.o"
"$fc" -O3 -ffree-line-length-none -o "$out/bench" \
  "$out/kernel.o" harness/bench_vmec_jacobian.f90
t1=$(date +%s.%N)
build_seconds=$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.6f", b-a }')

"$time_cmd" -v taskset -c 0 "$out/bench" > "$out/fortran.out" \
  2> "$out/fortran.time"
printf 'build_seconds=%s\n' "$build_seconds"
cat "$out/fortran.out"
cat "$out/fortran.time"
size "$out/kernel.o" "$out/bench"
