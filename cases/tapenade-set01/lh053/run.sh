#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
result="$case_dir/result.txt"
fortad_pin=db0050259520b618e2a0aeba203c85a7613943b5
tapenade_pin=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh053"
out=$(mktemp -d /var/tmp/fortad-set01-lh053.XXXXXX)
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
grep -Fq 'Nonstandard type declaration REAL*8' "$out/upstream_program.log"
grep -Fq 'Cannot open included file' "$out/upstream_program_dv.log"

tapenade="$tapenade_repo/bin/tapenade"
(cd "$out/parser" && "$tapenade" -p -root cg12v4 -o lh053 "$source_dir/program.f") >"$out/parser.log" 2>&1
(cd "$out/forward" && "$tapenade" -d -root cg12v4 -o lh053 "$source_dir/program.f") >"$out/forward.log" 2>&1
(cd "$out/reverse" && "$tapenade" -b -root cg12v4 -o lh053 "$source_dir/program.f") >"$out/reverse.log" 2>&1
for f in "$out/parser/lh053_p.f" "$out/forward/lh053_d.f" "$out/reverse/lh053_b.f"; do test -s "$f"; done
compile_fixed "$out/parser/lh053_p.f" tapenade_parser
compile_fixed "$out/forward/lh053_d.f" tapenade_forward
compile_fixed "$out/reverse/lh053_b.f" tapenade_reverse
for label in tapenade_parser tapenade_forward tapenade_reverse; do
    test "$(cat "$out/$label.status")" -ne 0
    grep -Fq 'Nonstandard type declaration REAL*8' "$out/$label.log"
done

fortad="$fortad_repo/build/fo/bin/fortad"
test -x "$fortad"
set +e
"$fortad" --mode forward --indep z,tk --dep gamai --proc cg12v4 --name exact_f --module exact_f_mod --output "$out/exact_f.f90" "$source_dir/program.f" >"$out/exact_f.log" 2>&1
exact_f=$?
"$fortad" --mode reverse --indep z,tk --dep gamai --proc cg12v4 --name exact_b --module exact_b_mod --output "$out/exact_b.f90" "$source_dir/program.f" >"$out/exact_b.log" 2>&1
exact_b=$?
"$fortad" --mode forward --indep z,tk,rcal --dep gamai --proc set01_lh053 --name lh053_f --module lh053_forward_mod --output "$out/fortad/lh053_f.f90" "$case_dir/port.f90" >"$out/port_f.log" 2>&1
port_f=$?
"$fortad" --mode reverse --indep z,tk,rcal --dep gamai --proc set01_lh053 --name lh053_b --module lh053_reverse_mod --output "$out/fortad/lh053_b.f90" "$case_dir/port.f90" >"$out/port_b.log" 2>&1
port_b=$?
set -e
test "$exact_f" -ne 0; test "$exact_b" -ne 0
grep -Fq 'could not locate the end of this do construct' "$out/exact_f.log"
grep -Fq 'could not locate the end of this do construct' "$out/exact_b.log"
test "$port_f" = 0; test -s "$out/fortad/lh053_f.f90"
test "$port_b" -ne 0; grep -Fq "'g' is both read and written in the same loop" "$out/port_b.log"

compile_free() {
    local file=$1 obj=$2
    "$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -c "$file" -o "$obj"
}
compile_free "$case_dir/port.f90" "$out/port.o"
compile_free "$out/fortad/lh053_f.f90" "$out/generated.o"
compile_free "$case_dir/harness.f90" "$out/harness.o"
"$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" "$out/port.o" "$out/generated.o" "$out/harness.o"
"$out/harness" >"$out/harness.log"
grep -Fq 'harness_status: pass' "$out/harness.log"
oracle=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle"

{
    echo 'case: Tapenade nonRegressions set01 lh053'
    echo 'classification: expected-refusal-with-bounded-forward-port'
    echo "fortad_commit: $(git -C "$fortad_repo" rev-parse HEAD)"
    echo "tapenade_commit: $(git -C "$tapenade_repo" rev-parse HEAD)"
    echo 'upstream_strict_compile: expected-refusal for all exact and stored derivatives'
    echo 'tapenade_generation: parser=pass tangent=pass reverse=pass root=cg12v4'
    echo "tapenade_parser_strict_compile: expected-refusal status=$(cat "$out/tapenade_parser.status")"
    echo "tapenade_forward_strict_compile: expected-refusal status=$(cat "$out/tapenade_forward.status")"
    echo "tapenade_reverse_strict_compile: expected-refusal status=$(cat "$out/tapenade_reverse.status")"
    echo "fortad_exact_forward: expected-refusal status=$exact_f diagnostic=could-not-locate-end-of-do"
    echo "fortad_exact_reverse: expected-refusal status=$exact_b diagnostic=could-not-locate-end-of-do"
    echo "fortad_port_forward: pass-transform-compile-runtime status=$port_f"
    echo "fortad_port_reverse: expected-refusal status=$port_b diagnostic=g-read-write-loop-storage"
    echo 'independent_oracle: hand chain-rule JVP, central-difference sweep, adjoint identity'
    echo "$oracle"
    cat "$out/harness.log"
    echo 'source_sha256:'
    (cd "$tapenade_repo" && sha256sum nonRegressions/set01/lh053/program*.f nonRegressions/set01/lh053/program*.msg)
    echo 'case_artifact_sha256:'
    (cd "$root" && sha256sum cases/tapenade-set01/lh053/manifest.toml cases/tapenade-set01/lh053/notes.md cases/tapenade-set01/lh053/port.f90 cases/tapenade-set01/lh053/oracle.py cases/tapenade-set01/lh053/harness.f90 cases/tapenade-set01/lh053/run.sh cases/tapenade-set01/lh053/test_contract.py)
} >"$result"
cat "$result"
