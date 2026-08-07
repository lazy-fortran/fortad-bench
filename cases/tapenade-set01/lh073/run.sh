#!/usr/bin/env bash
# Validate pinned Tapenade set01/lh073 with exact, fresh, and bounded evidence.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh073"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh073.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_checkout/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_checkout" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for source in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -f "$source_dir/$source"
done

if test ! -x "$tapenade_repo/bin/tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
if test ! -x "$fortad_checkout/build/fo/bin/fortad"; then
    (cd "$fortad_checkout" && fo build) >"$out/fortad-build.log" 2>&1
fi
fortad="$fortad_checkout/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
test -x "$fortad"
test -x "$tapenade"

mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/exact" "$out/bounded"

compile_fixed() {
    local source=$1 label=$2
    set +e
    "$fc" "${fixed_flags[@]}" -J"$out/mod" -I"$source_dir" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status"
}

compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status"
}

program_status=$(compile_fixed "$source_dir/program.f" upstream_program)
parser_status=$(compile_fixed "$source_dir/program_p.f" upstream_parser)
tangent_status=$(compile_fixed "$source_dir/program_d.f" upstream_tangent)
reverse_status=$(compile_fixed "$source_dir/program_b.f" upstream_reverse)
multidirectional_status=$(compile_fixed "$source_dir/program_dv.f" upstream_multidirectional)
test "$program_status" -eq 0
test "$parser_status" -eq 0
test "$tangent_status" -eq 0
test "$reverse_status" -eq 0
test "$multidirectional_status" -ne 0
grep -Fq 'Cannot open included file' "$out/upstream_multidirectional.stderr"

set +e
(cd "$out/tapenade/parser" && "$tapenade" -p -root top -O . -o lh073 \
    "$source_dir/program.f") >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
parser_generation_status=$?
(cd "$out/tapenade/forward" && "$tapenade" -d -root top -O . -o lh073 \
    "$source_dir/program.f") >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
tangent_generation_status=$?
(cd "$out/tapenade/reverse" && "$tapenade" -b -root top -O . -o lh073 \
    "$source_dir/program.f") >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
reverse_generation_status=$?
set -e
test "$parser_generation_status" -eq 0
test "$tangent_generation_status" -eq 0
test "$reverse_generation_status" -eq 0
for generated in "$out/tapenade/parser/lh073_p.f" \
    "$out/tapenade/forward/lh073_d.f" "$out/tapenade/reverse/lh073_b.f"; do
    test -s "$generated"
done
fresh_parser_status=$(compile_fixed "$out/tapenade/parser/lh073_p.f" fresh_parser)
fresh_tangent_status=$(compile_fixed "$out/tapenade/forward/lh073_d.f" fresh_tangent)
fresh_reverse_status=$(compile_fixed "$out/tapenade/reverse/lh073_b.f" fresh_reverse)
test "$fresh_parser_status" -eq 0
test "$fresh_tangent_status" -eq 0
test "$fresh_reverse_status" -eq 0

set +e
"$fortad" --mode forward --indep A,B --proc top --name lh073_exact_forward \
    --module lh073_exact_forward_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f" >"$out/exact/forward.stdout" 2>"$out/exact/forward.stderr"
exact_forward_status=$?
"$fortad" --mode reverse --indep A,B --dep A --proc top --name lh073_exact_reverse \
    --module lh073_exact_reverse_mod --output "$out/exact/reverse.f90" \
    "$source_dir/program.f" >"$out/exact/reverse.stdout" 2>"$out/exact/reverse.stderr"
exact_reverse_status=$?
set -e
test "$exact_forward_status" -ne 0
test "$exact_reverse_status" -ne 0
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
grep -Fq 'inlining toto would need a statement form it does not have' \
    "$out/exact/forward.stderr"
grep -Fq 'inlining toto would need a statement form it does not have' \
    "$out/exact/reverse.stderr"

set +e
"$fortad" --mode forward --indep a_in,b_in --proc set01_lh073 \
    --name lh073_forward --module lh073_forward_mod \
    --output "$out/bounded/forward.f90" "$case_dir/port.f90" \
    >"$out/bounded/forward.stdout" 2>"$out/bounded/forward.stderr"
bounded_forward_transform_status=$?
"$fortad" --mode reverse --no-primal --indep a_in,b_in --dep objective \
    --proc set01_lh073 --name lh073_reverse --module lh073_reverse_mod \
    --output "$out/bounded/reverse.f90" "$case_dir/port.f90" \
    >"$out/bounded/reverse.stdout" 2>"$out/bounded/reverse.stderr"
bounded_reverse_transform_status=$?
set -e
test "$bounded_forward_transform_status" -eq 0
test "$bounded_reverse_transform_status" -eq 0
test -s "$out/bounded/forward.f90"
test -s "$out/bounded/reverse.f90"

port_status=$(compile_free "$case_dir/port.f90" bounded_port)
hand_status=$(compile_free "$case_dir/hand.f90" bounded_hand)
bounded_forward_compile_status=$(compile_free "$out/bounded/forward.f90" bounded_forward)
bounded_reverse_compile_status=$(compile_free "$out/bounded/reverse.f90" bounded_reverse)
test "$port_status" -eq 0
test "$hand_status" -eq 0
test "$bounded_forward_compile_status" -eq 0
test "$bounded_reverse_compile_status" -eq 0

harness_compile_status=$(compile_free "$case_dir/harness.f90" harness)
test "$harness_compile_status" -eq 0
"$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" \
    "$out/bounded_port.o" "$out/bounded_hand.o" "$out/bounded_forward.o" \
    "$out/bounded_reverse.o" "$out/harness.o" >"$out/link.stdout" 2>"$out/link.stderr"
"$out/harness" >"$out/harness.stdout"
grep -Fq 'harness_status: pass' "$out/harness.stdout"
oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh073\n'
    printf 'classification: expected-refusal-with-bounded-concrete-callback-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${fixed_flags[*]}"
    printf 'strict_free_flags: %s\n' "${free_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_checkout" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'entry_point: top(A,B)\n'
    printf 'tapenade_options: parser=-p/-root top tangent=-d/-root top reverse=-b/-root top\n'
    printf 'upstream_exact_strict_compile: program=%s parser=%s tangent=%s reverse=%s multidirectional=%s\n' \
        "$program_status" "$parser_status" "$tangent_status" "$reverse_status" "$multidirectional_status"
    printf 'upstream_multidirectional_diagnostic: missing-DIFFSIZES.inc\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$parser_generation_status" "$tangent_generation_status" "$reverse_generation_status"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$fresh_parser_status" "$fresh_tangent_status" "$fresh_reverse_status"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="inlining toto would need a statement form it does not have"\n' \
        "$exact_forward_status"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="inlining toto would need a statement form it does not have"\n' \
        "$exact_reverse_status"
    printf 'fortad_bounded_forward: transform=%s compile=%s runtime=pass\n' \
        "$bounded_forward_transform_status" "$bounded_forward_compile_status"
    printf 'fortad_bounded_reverse_objective: transform=%s compile=%s runtime=pass\n' \
        "$bounded_reverse_transform_status" "$bounded_reverse_compile_status"
    printf 'bounded_port_strict_compile: %s\n' "$port_status"
    printf 'bounded_hand_strict_compile: %s\n' "$hand_status"
    printf 'bounded_harness_strict_compile: %s\n' "$harness_compile_status"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    cat "$out/harness.stdout"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh073_p.f lh073_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh073_d.f lh073_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh073_b.f lh073_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh073/manifest.toml \
        cases/tapenade-set01/lh073/notes.md cases/tapenade-set01/lh073/port.f90 \
        cases/tapenade-set01/lh073/hand.f90 cases/tapenade-set01/lh073/oracle.py \
        cases/tapenade-set01/lh073/harness.f90 cases/tapenade-set01/lh073/run.sh \
        cases/tapenade-set01/lh073/test_contract.py)
} >"$result"
cat "$result"
