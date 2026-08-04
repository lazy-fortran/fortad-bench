#!/usr/bin/env bash
# Build-time comparison: fortad against the Enzyme toolchain path.
#
# Runtime is only half of fortad's goal. This measures the other half, and it
# measures it in the shape a user actually experiences: from an unmodified
# primal to a compiled derivative object, and again after a one-line edit to
# the primal, because incremental rebuild is what a developer pays repeatedly.
#
# What this does NOT measure, and what the numbers must not be read as
# including: building or installing a matching LLVM and the Enzyme plugin.
# That is a real cost fortad does not have at all, but it is paid once and
# amortised, so folding it in here would flatter fortad dishonestly.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
fortad_bin=$(find "$fortad_repo/build" -name fortad -type f -perm -u+x 2>/dev/null | head -1)
[ -n "$fortad_bin" ] || { echo "build fortad first" >&2; exit 1; }

flang=${FLANG:-flang}
clang=${CLANG:-clang}
opt=${OPT:-opt}
llvm_link=${LLVM_LINK:-llvm-link}
plugin=${ENZYME_PLUGIN:-$HOME/code/enzyme/install-llvm22/lib/LLVMEnzyme-22.so}

out=build/buildtime
rm -rf "$out"
mkdir -p "$out" results
cp cases/dot_sin/primal_plain.f90 "$out/primal.f90"
cp cases/dot_sin/kernel.f90 "$out/kernel.f90"

REPS=${REPS:-5}

now() { date +%s.%N; }
elapsed() { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.4f", b-a}'; }

time_fortad() {
    local t0 t1
    t0=$(now)
    "$fortad_bin" --mode reverse --indep a,b --module k_adj \
        -o "$out/adj.f90" "$out/primal.f90" >/dev/null
    "$flang" -O3 -c "$out/adj.f90" -o "$out/adj.o" -module-dir "$out" 2>/dev/null \
        || "$flang" -O3 -c "$out/adj.f90" -o "$out/adj.o"
    t1=$(now)
    elapsed "$t0" "$t1"
}

time_enzyme() {
    local t0 t1
    t0=$(now)
    "$flang" -O3 -fPIC -S -emit-llvm "$out/kernel.f90" -o "$out/kernel.ll" 2>/dev/null
    "$clang" -O3 -fPIC -S -emit-llvm engines/enzyme_wrapper.c -o "$out/wrapper.ll"
    "$llvm_link" -S "$out/kernel.ll" "$out/wrapper.ll" -o "$out/linked.ll"
    "$opt" -load-pass-plugin="$plugin" -passes=enzyme "$out/linked.ll" -S \
        -o "$out/enzyme.ll"
    "$opt" -O3 "$out/enzyme.ll" -S -o "$out/enzyme_opt.ll"
    "$clang" -O3 -fPIC -c "$out/enzyme_opt.ll" -o "$out/enzyme.o"
    t1=$(now)
    elapsed "$t0" "$t1"
}

echo "engine,scenario,seconds" > results/buildtime.csv

echo "cold build, best of $REPS:"
best_f=999; best_e=999
for _ in $(seq "$REPS"); do
    s=$(time_fortad); best_f=$(awk -v a="$s" -v b="$best_f" 'BEGIN{print (a<b)?a:b}')
    s=$(time_enzyme); best_e=$(awk -v a="$s" -v b="$best_e" 'BEGIN{print (a<b)?a:b}')
done
echo "fortad,cold,$best_f" >> results/buildtime.csv
echo "enzyme,cold,$best_e" >> results/buildtime.csv
printf '  fortad %ss   enzyme %ss\n' "$best_f" "$best_e"

echo "after a one-line edit to the primal, best of $REPS:"
best_f=999; best_e=999
for i in $(seq "$REPS"); do
    sed -i "s/0\.0d0/0.0d0/" "$out/primal.f90"
    printf '! touch %s\n' "$i" >> "$out/primal.f90"
    printf '! touch %s\n' "$i" >> "$out/kernel.f90"
    s=$(time_fortad); best_f=$(awk -v a="$s" -v b="$best_f" 'BEGIN{print (a<b)?a:b}')
    s=$(time_enzyme); best_e=$(awk -v a="$s" -v b="$best_e" 'BEGIN{print (a<b)?a:b}')
done
echo "fortad,incremental,$best_f" >> results/buildtime.csv
echo "enzyme,incremental,$best_e" >> results/buildtime.csv
printf '  fortad %ss   enzyme %ss\n' "$best_f" "$best_e"

echo
echo "generated object sizes:"
ls -l "$out/adj.o" "$out/enzyme.o" | awk '{printf "  %-12s %s bytes\n", $NF, $5}'
echo
cat results/buildtime.csv
