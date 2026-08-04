#!/usr/bin/env bash
# Compile fortad's generated derivative code with every Fortran compiler on
# this machine, and check that gfortran vectorises the kernels.
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

"$fortad_bin" --mode reverse --indep a,b --module k_adjoint \
    -o "$out/adjoint.f90" cases/dot_sin/primal_plain.f90 || exit 1
"$fortad_bin" --indep a,b --module k_tangent \
    -o "$out/tangent.f90" cases/dot_sin/primal_plain.f90 || exit 1
"$fortad_bin" --indep a,b -d n_dir --module k_tangent_v \
    -o "$out/tangent_v.f90" cases/dot_sin/primal_plain.f90 || exit 1

echo "compiler,file,result" > results/compiler_matrix.csv
failures=0

for fc in gfortran flang ifx ifort nvfortran lfortran; do
    command -v "$fc" >/dev/null 2>&1 || continue
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
echo "vectorisation report (gfortran):"
( cd "$out" && gfortran -O3 -march=native -fopt-info-vec -c adjoint.f90 \
    -o adjoint.vec.o ) 2>"$out/vec.log"
if grep -q "loop vectorized" "$out/vec.log"; then
    echo "  adjoint loop vectorized"
    echo "gfortran,adjoint,vectorized" >> results/compiler_matrix.csv
else
    echo "  adjoint loop NOT vectorized - see $out/vec.log"
    echo "gfortran,adjoint,not-vectorized" >> results/compiler_matrix.csv
    failures=$((failures + 1))
fi

echo
if [ "$failures" -eq 0 ]; then
    echo "all compilers accepted the generated code"
else
    echo "$failures failure(s)"
fi
cat results/compiler_matrix.csv
exit "$failures"
