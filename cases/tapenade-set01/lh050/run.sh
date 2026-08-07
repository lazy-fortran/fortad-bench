#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh050 and the bounded FortAD probe.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh050"
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh050"

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v /usr/bin/time >/dev/null
test "$(git -C "$fortad_checkout" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_d.f program_b.f program_d.msg program_b.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh050.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/exact" "$out/port" "$out/mod"

compile_fixed() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_fixed[@]}" -c "$source" -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

for source in program program_d program_b; do
    compile_fixed "$source_dir/$source.f" "exact_$source"
done
test "$(cat "$out/exact_program.status")" = 0
test "$(cat "$out/exact_program_d.status")" = 0
test "$(cat "$out/exact_program_b.status")" != 0
grep -Fq 'INTEGER*4' "$out/exact_program_b.stderr"

tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade" || test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
for mode in p d b; do
    case "$mode" in p) dir=parser;; d) dir=forward;; b) dir=reverse;; esac
    (cd "$out/tapenade/$dir" && "$tapenade" "-$mode" -root sub0 -O . -o lh050 "$source_dir/program.f") >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr"
done
test -s "$out/tapenade/parser/lh050_p.f"
test -s "$out/tapenade/forward/lh050_d.f"
test -s "$out/tapenade/reverse/lh050_b.f"
compile_fixed "$out/tapenade/parser/lh050_p.f" fresh_parser
compile_fixed "$out/tapenade/forward/lh050_d.f" fresh_tangent
compile_fixed "$out/tapenade/reverse/lh050_b.f" fresh_reverse
test "$(cat "$out/fresh_parser.status")" = 0
test "$(cat "$out/fresh_tangent.status")" = 0
test "$(cat "$out/fresh_reverse.status")" != 0
grep -Fq 'INTEGER*4' "$out/fresh_reverse.stderr"

fortad="$fortad_checkout/build/fo/bin/fortad"
(cd "$fortad_checkout" && FO_JOBS=1 fo build) >"$out/fortad-build.log" 2>&1
test -x "$fortad"

"$fortad" --mode forward --indep x,y --dep z --proc sub0 --name lh050_exact_forward --module lh050_exact_forward_mod --output "$out/exact/forward.f90" "$source_dir/program.f" >"$out/exact/forward.stdout" 2>"$out/exact/forward.stderr"
"$fortad" --mode reverse --indep x,y --dep z --proc sub0 --name lh050_exact_reverse --module lh050_exact_reverse_mod --output "$out/exact/reverse.f90" "$source_dir/program.f" >"$out/exact/reverse.stdout" 2>"$out/exact/reverse.stderr"
compile_free "$out/exact/forward.f90" exact_fortad_forward
compile_free "$out/exact/reverse.f90" exact_fortad_reverse
test "$(cat "$out/exact_fortad_forward.status")" = 0
test "$(cat "$out/exact_fortad_reverse.status")" = 0

"$fortad" --mode forward --indep x,y,z --dep z --proc set01_lh050 --name lh050_port_forward --module lh050_port_forward_mod --output "$out/port/forward.f90" "$case_dir/port.f90" >"$out/port/forward.stdout" 2>"$out/port/forward.stderr"
"$fortad" --mode reverse --indep x,y --dep z --proc set01_lh050 --name lh050_port_reverse --module lh050_port_reverse_mod --output "$out/port/reverse.f90" "$case_dir/port.f90" >"$out/port/reverse.stdout" 2>"$out/port/reverse.stderr"
compile_free "$case_dir/port.f90" port
compile_free "$case_dir/hand.f90" hand
compile_free "$out/exact/forward.f90" exact_forward
compile_free "$out/exact/reverse.f90" exact_reverse
compile_free "$out/port/forward.f90" port_forward
compile_free "$out/port/reverse.f90" port_reverse
compile_free "$case_dir/harness.f90" harness
test "$(cat "$out/port.status")" = 0
test "$(cat "$out/hand.status")" = 0
test "$(cat "$out/exact_forward.status")" = 0
test "$(cat "$out/exact_reverse.status")" = 0
test "$(cat "$out/port_forward.status")" = 0
test "$(cat "$out/port_reverse.status")" != 0
grep -Fq 'z_b = z_b + z_v2_b' "$out/port_reverse.stderr"
test "$(cat "$out/harness.status")" = 0
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" "$out/hand.o" "$out/exact_forward.o" "$out/exact_reverse.o" "$out/port_forward.o" "$out/harness.o"
"$out/harness" >"$out/harness.run"
grep -Fqx 'exact_forward_oracle: mismatch' "$out/harness.run"
grep -Fqx 'exact_reverse_oracle: mismatch' "$out/harness.run"
grep -Fqx 'bounded_forward_oracle: pass' "$out/harness.run"
grep -Fqx 'oracle_status: pass' "$out/harness.run"
python3 "$case_dir/oracle.py" >"$out/python-oracle.txt"
grep -Fqx 'oracle_status: pass' "$out/python-oracle.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh050\n'
    printf 'classification: fortad-semantic-mismatch-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_checkout" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'entry_point: sub0(x,y,z); options: -p | -d -root sub0 | -b -root sub0\n'
    printf 'bounded_entry_point: set01_lh050(x,y,z); independent: x,y; dependent: y,z\n'
    printf 'commands: exact strict compile; fresh tapenade -p/-d/-b -root sub0; FortAD exact --mode forward/reverse; bounded --mode forward/reverse\n'
    printf 'upstream_exact_strict_compile: program=0 tangent=0 reverse=1 diagnostic="INTEGER*4"\n'
    printf 'stored_references: program_d.f program_b.f program_d.msg program_b.msg\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=0 tangent=0 reverse=1 diagnostic="INTEGER*4"\n'
    printf 'fortad_exact_generation: forward=pass reverse=pass\n'
    printf 'fortad_exact_strict_compile: forward=0 reverse=0\n'
    printf 'fortad_exact_independent_oracle: forward=mismatch reverse=mismatch; conditional body omitted on x>0\n'
    printf 'fortad_bounded_forward: generation=pass strict_compile=0 runtime=pass\n'
    printf 'fortad_bounded_reverse: generation=pass strict_compile=1 diagnostic="z_b = z_b + z_v2_b"\n'
    printf 'independent_oracle: closed-form hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/harness.run"
    cat "$out/python-oracle.txt"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_d.f program_b.f program_d.msg program_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh050/manifest.toml cases/tapenade-set01/lh050/notes.md cases/tapenade-set01/lh050/port.f90 cases/tapenade-set01/lh050/hand.f90 cases/tapenade-set01/lh050/harness.f90 cases/tapenade-set01/lh050/oracle.py cases/tapenade-set01/lh050/run.sh cases/tapenade-set01/lh050/test_contract.py)
} >"$result"
cat "$result"
