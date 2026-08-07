#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if [[ ! -d "$fortad_repo/.git" && -d /home/ert/code/lazy-fortran/fortad/.git ]]; then
    fortad_repo=/home/ert/code/lazy-fortran/fortad
fi
if [[ ! -d "$tapenade_repo/.git" && -d /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git ]]; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi

result="$case_dir/result.txt"
fortad_pin=0e156041c1f92736c1e35f8164b37992c4c8d780
tapenade_pin=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh055"
out=$(mktemp -d /var/tmp/fortad-set01-lh055.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/parser" "$out/forward" "$out/reverse" "$out/fortad" "$out/mod"

test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$fortad_pin"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$tapenade_pin"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for f in program.f program_p.f program_d.f program_b.f program_dv.f program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -s "$source_dir/$f"
done

compile_fixed() {
    local file=$1 label=$2
    set +e
    "$fc" "${fixed[@]}" -c "$file" -o "$out/$label.o" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    echo "$status" >"$out/$label.status"
}

for f in program.f program_p.f program_d.f program_b.f program_dv.f; do
    compile_fixed "$source_dir/$f" "upstream_${f%.f}"
    test "$(cat "$out/upstream_${f%.f}.status")" -ne 0
done
for f in program program_p program_d program_b; do
    grep -Fq 'Nonstandard type declaration REAL*8' "$out/upstream_${f}.log"
done
grep -Fq 'Cannot open included file' "$out/upstream_program_dv.log"

tapenade="$tapenade_repo/bin/tapenade"
(cd "$out/parser" && "$tapenade" -p -root test -o lh055 "$source_dir/program.f") >"$out/parser.log" 2>&1
(cd "$out/forward" && "$tapenade" -d -root test -o lh055 "$source_dir/program.f") >"$out/forward.log" 2>&1
(cd "$out/reverse" && "$tapenade" -b -root test -o lh055 "$source_dir/program.f") >"$out/reverse.log" 2>&1
for f in "$out/parser/lh055_p.f" "$out/forward/lh055_d.f" "$out/reverse/lh055_b.f"; do
    test -s "$f"
done
compile_fixed "$out/parser/lh055_p.f" tapenade_parser
compile_fixed "$out/forward/lh055_d.f" tapenade_forward
compile_fixed "$out/reverse/lh055_b.f" tapenade_reverse
for label in tapenade_parser tapenade_forward tapenade_reverse; do
    test "$(cat "$out/$label.status")" -ne 0
    grep -Fq 'Nonstandard type declaration REAL*8' "$out/$label.log"
done

fortad="$fortad_repo/build/fo/bin/fortad"
test -x "$fortad"
set +e
"$fortad" --mode forward --indep b --dep a --proc test --name test_f --module test_f_mod --output "$out/test_f.f90" "$source_dir/program.f" >"$out/exact_forward.log" 2>&1
exact_f=$?
"$fortad" --mode reverse --indep b --dep a --proc test --name test_b --module test_b_mod --output "$out/test_b.f90" "$source_dir/program.f" >"$out/exact_reverse.log" 2>&1
exact_b=$?
set -e
test "$exact_f" -ne 0
test "$exact_b" -ne 0
grep -Fq "fortad: independent 'b' is not declared in TEST" "$out/exact_forward.log"
grep -Fq "fortad: dependent 'a' is not declared in TEST" "$out/exact_reverse.log"

set +e
"$fortad" --mode forward --indep b --dep a --proc set01_lh055 --name lh055_forward --module lh055_forward_mod --output "$out/fortad/lh055_forward.f90" "$case_dir/port.f90" >"$out/port_forward.log" 2>&1
port_f=$?
"$fortad" --mode reverse --indep b --dep a --proc set01_lh055 --name lh055_reverse --module lh055_reverse_mod --output "$out/fortad/lh055_reverse.f90" "$case_dir/port.f90" >"$out/port_reverse.log" 2>&1
port_b=$?
set -e
test "$port_f" = 0
test "$port_b" = 0
test -s "$out/fortad/lh055_forward.f90"
test -s "$out/fortad/lh055_reverse.f90"

compile_free() {
    local file=$1 obj=$2
    "$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -c "$file" -o "$obj"
}
compile_free "$case_dir/port.f90" "$out/port.o"
compile_free "$out/fortad/lh055_forward.f90" "$out/forward.o"
compile_free "$out/fortad/lh055_reverse.f90" "$out/reverse.o"
compile_free "$case_dir/harness.f90" "$out/harness.o"
"$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" \
    "$out/port.o" "$out/forward.o" "$out/reverse.o" "$out/harness.o"
"$out/harness" >"$out/harness.log"
grep -Fq 'harness_status: pass' "$out/harness.log"
oracle=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle"

{
    echo 'case: Tapenade nonRegressions set01 lh055'
    echo 'classification: expected-refusal-with-bounded-forward-port'
    echo "fortad_commit: $(git -C "$fortad_repo" rev-parse HEAD)"
    echo "tapenade_commit: $(git -C "$tapenade_repo" rev-parse HEAD)"
    echo "strict_fixed_flags: ${fixed[*]}"
    echo 'upstream_exact_strict_compile: expected-refusal program=1 program_p=1 program_d=1 program_b=1 program_dv=1'
    echo 'upstream_stored_reference_strict_compile: program_p=1 program_d=1 program_b=1 program_dv=1'
    echo 'upstream_diagnostic_contract: REAL*8 in scalar files; program_dv missing DIFFSIZES.inc'
    echo 'tapenade_generation: parser=pass tangent=pass reverse=pass root=test'
    echo 'tapenade_generated_strict_compile: parser=expected-refusal tangent=expected-refusal reverse=expected-refusal'
    echo "fortad_exact_forward: expected-refusal status=$exact_f diagnostic=independent-b-not-declared"
    echo "fortad_exact_reverse: expected-refusal status=$exact_b diagnostic=dependent-a-not-declared"
    echo "fortad_port_forward: pass-transform-compile-runtime status=$port_f"
    echo "fortad_port_reverse: pass-transform-compile-runtime status=$port_b"
    echo 'independent_oracle: hand JVP/VJP, central-difference sweep, adjoint identity'
    echo "$oracle"
    cat "$out/harness.log"
    echo 'commands:'
    echo "tapenade_parser: (cd <out>/parser && $tapenade -p -root test -o lh055 $source_dir/program.f)"
    echo "tapenade_forward: (cd <out>/forward && $tapenade -d -root test -o lh055 $source_dir/program.f)"
    echo "tapenade_reverse: (cd <out>/reverse && $tapenade -b -root test -o lh055 $source_dir/program.f)"
    echo "fortad_exact_forward: $fortad --mode forward --indep b --dep a --proc test --name test_f --module test_f_mod --output <out>/test_f.f90 $source_dir/program.f"
    echo "fortad_exact_reverse: $fortad --mode reverse --indep b --dep a --proc test --name test_b --module test_b_mod --output <out>/test_b.f90 $source_dir/program.f"
    echo "fortad_port_forward: $fortad --mode forward --indep b --dep a --proc set01_lh055 --name lh055_forward --module lh055_forward_mod --output <out>/fortad/lh055_forward.f90 $case_dir/port.f90"
    echo "fortad_port_reverse: $fortad --mode reverse --indep b --dep a --proc set01_lh055 --name lh055_reverse --module lh055_reverse_mod --output <out>/fortad/lh055_reverse.f90 $case_dir/port.f90"
    echo 'source_sha256:'
    (cd "$tapenade_repo" && sha256sum nonRegressions/set01/lh055/program*.f nonRegressions/set01/lh055/program*.msg)
    echo 'case_artifact_sha256:'
    (cd "$root" && sha256sum cases/tapenade-set01/lh055/manifest.toml cases/tapenade-set01/lh055/notes.md cases/tapenade-set01/lh055/port.f90 cases/tapenade-set01/lh055/oracle.py cases/tapenade-set01/lh055/harness.f90 cases/tapenade-set01/lh055/run.sh cases/tapenade-set01/lh055/test_contract.py)
} >"$result"
cat "$result"
