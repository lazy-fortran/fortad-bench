#!/usr/bin/env bash
# Build the Enzyme baseline for one case. Requires flang, clang, opt and
# llvm-link from the SAME LLVM as the Enzyme plugin - that version coupling is
# itself one of the things this benchmark measures.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir=${1:?usage: build_enzyme.sh <case-dir> <out-dir>}
out=${2:?usage: build_enzyme.sh <case-dir> <out-dir>}

flang=${FLANG:-flang}
clang=${CLANG:-clang}
opt=${OPT:-opt}
llvm_link=${LLVM_LINK:-llvm-link}
plugin=${ENZYME_PLUGIN:-$HOME/code/enzyme/install-llvm22/lib/LLVMEnzyme-22.so}

test -f "$plugin" || { echo "no Enzyme plugin at $plugin" >&2; exit 1; }
mkdir -p "$out"

"$flang" -O3 -fPIC -S -emit-llvm "$case_dir/kernel.f90" -o "$out/kernel.ll"
"$clang" -O3 -fPIC -S -emit-llvm "$root/engines/enzyme_wrapper.c" \
    -o "$out/wrapper.ll"
"$llvm_link" -S "$out/kernel.ll" "$out/wrapper.ll" -o "$out/linked.ll"
"$opt" -load-pass-plugin="$plugin" -passes=enzyme "$out/linked.ll" -S \
    -o "$out/enzyme.ll"
"$opt" -O3 "$out/enzyme.ll" -S -o "$out/enzyme_opt.ll"
"$clang" -O3 -fPIC -c "$out/enzyme_opt.ll" -o "$out/enzyme.o"
