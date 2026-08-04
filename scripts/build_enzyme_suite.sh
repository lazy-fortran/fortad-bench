#!/usr/bin/env bash
# Build every workload of the Enzyme suite for both engines.
#
# Enzyme goes through the documented flang -> LLVM IR -> opt -passes=enzyme
# route. fortad reads the same numerical kernel as plain Fortran. Both are then
# compiled by the same flang, so the comparison is of the derivative code and
# not of two different compilers.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

flang=${FLANG:-flang}
clang=${CLANG:-clang}
opt=${OPT:-opt}
llvm_link=${LLVM_LINK:-llvm-link}
plugin=${ENZYME_PLUGIN:-$HOME/code/enzyme/install-llvm22/lib/LLVMEnzyme-22.so}
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
# fo is the project's build driver. It is also what keeps this honest: fpm
# leaves an app binary unrelinked often enough that a stale fortad silently
# regenerates the previous kernels, and a benchmark run against those measures
# nothing.
if [ ! -x "$fortad_repo/build/fo/bin/fortad" ]; then
    ( cd "$fortad_repo" && fo build >/dev/null )
fi
fortad_bin="$fortad_repo/build/fo/bin/fortad"

out=build/enzyme_suite
rm -rf "$out"
mkdir -p "$out" results

# ba is out for now: it writes qx three times in the loop body, and reverse
# mode refuses a scalar written more than once there. The refusal is honest -
# the alternative attempt produced a wrong gradient, which this suite's
# cross-check caught - and it is the next thing to fix.
WORKLOADS="euler rk4 lstm bruss"

echo "== Enzyme"
for k in $WORKLOADS; do
    "$flang" -O3 -fPIC -S -emit-llvm "cases/enzyme_suite/kernels/${k}_c.f90" \
        -o "$out/$k.ll" -module-dir "$out"
done
"$clang" -O3 -fPIC -S -emit-llvm engines/enzyme_suite.c -o "$out/wrapper.ll"
# shellcheck disable=SC2086
"$llvm_link" -S $(for k in $WORKLOADS; do echo "$out/$k.ll"; done) \
    "$out/wrapper.ll" -o "$out/linked.ll"
"$opt" -load-pass-plugin="$plugin" -passes=enzyme "$out/linked.ll" -S \
    -o "$out/enzyme.ll"
"$opt" -O3 "$out/enzyme.ll" -S -o "$out/enzyme_opt.ll"
"$clang" -O3 -fPIC -c "$out/enzyme_opt.ll" -o "$out/enzyme.o"

echo "== fortad"
for k in $WORKLOADS; do
    "$fortad_bin" --mode reverse --indep z --name "${k}_vjp" \
        -o "$out/${k}_vjp.f90" "cases/enzyme_suite/kernels/$k.f90"
    "$flang" -O3 -c "$out/${k}_vjp.f90" -o "$out/${k}_vjp.o" -module-dir "$out"
    # Gradient-only: the same contract Tapenade's reverse routine offers.
    "$fortad_bin" --mode reverse --indep z --no-primal --name "${k}_grad" \
        -o "$out/${k}_grad.f90" "cases/enzyme_suite/kernels/$k.f90"
    "$flang" -O3 -c "$out/${k}_grad.f90" -o "$out/${k}_grad.o" -module-dir "$out"
done

echo "== tapenade"
./scripts/build_tapenade.sh > /dev/null
tap=build/tapenade
( cd "$tap/ADFirstAidKit" && clang -O3 -w -c adStack.c -o adStack.o )
for k in $WORKLOADS; do
    "$flang" -O3 -c "$tap/${k}_tap_b.f90" -o "$tap/${k}_b.o" -module-dir "$tap"
done

echo "== driver"
"$flang" -O3 -o "$out/bench" harness/bench_enzyme_suite.f90 \
    $(for k in $WORKLOADS; do echo "$out/${k}_vjp.o" "$out/${k}_grad.o"; done) \
    "$out/enzyme.o" \
    $(for k in $WORKLOADS; do echo "$tap/${k}_b.o"; done) \
    "$tap/ADFirstAidKit/adStack.o"
echo "built $out/bench"
