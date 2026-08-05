#!/usr/bin/env bash
# Compile fortad's generated derivative code with every compiler required by
# P6.1, and make unavailable compilers visible instead of silently skipping
# them. The script is a portability check, not evidence that every compiler
# vectorises every kernel.
#
# "Emits standard Fortran that any conforming compiler builds" is fortad's
# central product claim. A claim nobody checks is a wish, so this checks it.
#
# The vectorisation gate matters just as much: correct code the compiler
# refuses to vectorise is a failed generation, because it means the emitter
# obstructed the optimiser the whole design depends on.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
fortad_bin=$(find "$fortad_repo/build" -name fortad -type f -perm -u+x 2>/dev/null | head -1)
if [ -z "$fortad_bin" ]; then
    ( cd "$fortad_repo" && fpm build >/dev/null ) || exit 1
    fortad_bin=$(find "$fortad_repo/build" -name fortad -type f -perm -u+x | head -1)
fi

out=build/compilers
mkdir -p "$out" results

source=cases/compiler_matrix/primal_plain.f90
"$fortad_bin" --mode reverse --indep a,b --module k_adjoint \
    -o "$out/adjoint.f90" "$source" || exit 1
"$fortad_bin" --indep a,b --module k_tangent \
    -o "$out/tangent.f90" "$source" || exit 1
"$fortad_bin" --indep a,b -d n_dir --module k_tangent_v \
    -o "$out/tangent_v.f90" "$source" || exit 1

echo "compiler,file,result" > results/compiler_matrix.csv
failures=0

for fc in gfortran flang-new ifx nvfortran lfortran; do
    if ! command -v "$fc" >/dev/null 2>&1; then
        echo "$fc,all,missing" >> results/compiler_matrix.csv
        printf '  %-10s unavailable\n' "$fc"
        failures=$((failures + 1))
        continue
    fi
    for f in adjoint tangent tangent_v; do
        if ( cd "$out" && "$fc" -c "$f.f90" -o "$f.$fc.o" ) >"$out/$f.$fc.log" 2>&1; then
            echo "$fc,$f,ok" >> results/compiler_matrix.csv
            printf '  %-10s %-10s ok\n' "$fc" "$f"
        else
            echo "$fc,$f,FAILED" >> results/compiler_matrix.csv
            printf '  %-10s %-10s FAILED (see %s)\n' "$fc" "$f" "$out/$f.$fc.log"
            failures=$((failures + 1))
        fi
    done
done

echo
echo "vectorisation reports (adjoint):"
vector_failures=0
if ( cd "$out" && gfortran -O3 -march=native -fopt-info-vec -c adjoint.f90 \
    -o adjoint.gfortran.vec.o ) 2>"$out/adjoint.gfortran.vec.log" \
    && grep -q "loop vectorized" "$out/adjoint.gfortran.vec.log"; then
    echo "  gfortran: vectorized"
    echo "gfortran,adjoint,vectorized" >> results/compiler_matrix.csv
else
    echo "  gfortran: NOT vectorized"
    echo "gfortran,adjoint,not-vectorized" >> results/compiler_matrix.csv
    vector_failures=$((vector_failures + 1))
fi

if ( cd "$out" && flang-new -O3 -ffast-math \
    -Rpass=loop-vectorize -Rpass-missed=loop-vectorize -c adjoint.f90 \
    -o adjoint.flang.vec.o ) 2>"$out/adjoint.flang.vec.log" \
    && grep -q "vectorized loop" "$out/adjoint.flang.vec.log"; then
    echo "  flang-new: vectorized"
    echo "flang-new,adjoint,vectorized" >> results/compiler_matrix.csv
else
    echo "  flang-new: NOT vectorized"
    echo "flang-new,adjoint,not-vectorized" >> results/compiler_matrix.csv
    vector_failures=$((vector_failures + 1))
fi

if ( cd "$out" && ifx -O3 -qopt-report=3 -qopt-report-phase=vec \
    -qopt-report-file="$PWD/adjoint.ifx.optrpt" -c adjoint.f90 \
    -o adjoint.ifx.vec.o ) >"$out/adjoint.ifx.vec.log" 2>&1 \
    && grep -q "LOOP WAS VECTORIZED" "$out/adjoint.ifx.optrpt"; then
    echo "  ifx: vectorized"
    echo "ifx,adjoint,vectorized" >> results/compiler_matrix.csv
else
    echo "  ifx: NOT vectorized"
    echo "ifx,adjoint,not-vectorized" >> results/compiler_matrix.csv
    vector_failures=$((vector_failures + 1))
fi

if ( cd "$out" && nvfortran -O3 -Minfo=vec -c adjoint.f90 \
    -o adjoint.nvfortran.vec.o ) 2>"$out/adjoint.nvfortran.vec.log" \
    && grep -q "Generated vector simd code" "$out/adjoint.nvfortran.vec.log"; then
    echo "  nvfortran: vectorized"
    echo "nvfortran,adjoint,vectorized" >> results/compiler_matrix.csv
else
    echo "  nvfortran: NOT vectorized"
    echo "nvfortran,adjoint,not-vectorized" >> results/compiler_matrix.csv
    vector_failures=$((vector_failures + 1))
fi

if ( cd "$out" && lfortran --backend llvm --fast --show-llvm adjoint.f90 \
    > adjoint.lfortran.ll 2>adjoint.lfortran.vec.log ) \
    && grep -Eq '<[0-9]+ x double>' "$out/adjoint.lfortran.ll"; then
    echo "  lfortran: vectorized LLVM IR"
    echo "lfortran,adjoint,vectorized" >> results/compiler_matrix.csv
else
    echo "  lfortran: NOT vectorized in LLVM IR"
    echo "lfortran,adjoint,not-vectorized" >> results/compiler_matrix.csv
    vector_failures=$((vector_failures + 1))
fi

failures=$((failures + vector_failures))

echo
if [ "$failures" -eq 0 ]; then
    echo "all compilers accepted the generated code"
else
    echo "$failures failure(s)"
fi
cat results/compiler_matrix.csv
exit "$failures"
