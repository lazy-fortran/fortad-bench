#!/usr/bin/env bash
# Validate pinned Tapenade set01/lh048 with exact, fresh, and bounded evidence.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_source=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_source=$(cd "$fortad_source" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors \
    -Wall -Wextra -Wimplicit-interface)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
    -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh048"

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -d "$fortad_source/.git" || test -f "$fortad_source/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_source" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_d.f program_b.f program_d.msg program_b.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh048.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/exact" "$out/port"

compile_capture() {
    local source=$1 object=$2 status_file=$3 form=$4
    local -a flags
    if test "$form" = fixed; then
        flags=("${strict_fixed[@]}")
    else
        flags=("${strict_free[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
    printf '%s\n' "$status"
}

exact_program_status=$(compile_capture "$source_dir/program.f" "$out/exact/program.o" "$out/exact/program.status" fixed)
exact_d_status=$(compile_capture "$source_dir/program_d.f" "$out/exact/program_d.o" "$out/exact/program_d.status" fixed)
exact_b_status=$(compile_capture "$source_dir/program_b.f" "$out/exact/program_b.o" "$out/exact/program_b.status" fixed)
test "$exact_program_status" -eq 0
test "$exact_d_status" -eq 0
test "$exact_b_status" -eq 0

tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
test -x "$tapenade"
(cd "$out/tapenade/parser" && "$tapenade" -p -O . -o lh048 "$source_dir/program.f") \
    >"$out/tapenade/parser.stdout" 2>"$out/tapenade/parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -root adj13bis -O . -o lh048 "$source_dir/program.f") \
    >"$out/tapenade/forward.stdout" 2>"$out/tapenade/forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -root adj13bis -O . -o lh048 "$source_dir/program.f") \
    >"$out/tapenade/reverse.stdout" 2>"$out/tapenade/reverse.stderr"
test -s "$out/tapenade/parser/lh048_p.f"
test -s "$out/tapenade/forward/lh048_d.f"
test -s "$out/tapenade/reverse/lh048_b.f"
fresh_p_status=$(compile_capture "$out/tapenade/parser/lh048_p.f" "$out/tapenade/parser.o" "$out/tapenade/parser.status" fixed)
fresh_d_status=$(compile_capture "$out/tapenade/forward/lh048_d.f" "$out/tapenade/forward.o" "$out/tapenade/forward.status" fixed)
fresh_b_status=$(compile_capture "$out/tapenade/reverse/lh048_b.f" "$out/tapenade/reverse.o" "$out/tapenade/reverse.status" fixed)
test "$fresh_p_status" -eq 0
test "$fresh_d_status" -eq 0
test "$fresh_b_status" -eq 0

fortad_exec() { (cd "$fortad_source" && fo exec --no-build fortad "$@"); }
set +e
fortad_exec --mode forward --indep u,z,t --proc adj13bis --name lh048_exact_jvp \
    --module lh048_exact_jvp_mod --output "$out/exact/forward.f90" "$source_dir/program.f" \
    >"$out/exact/forward.stdout" 2>"$out/exact/forward.stderr"
exact_fortad_forward_status=$?
fortad_exec --mode reverse --indep u,z,t --dep t --proc adj13bis --name lh048_exact_vjp \
    --module lh048_exact_vjp_mod --output "$out/exact/reverse.f90" "$source_dir/program.f" \
    >"$out/exact/reverse.stdout" 2>"$out/exact/reverse.stderr"
exact_fortad_reverse_status=$?
set -e
test "$exact_fortad_forward_status" -eq 1
test "$exact_fortad_reverse_status" -eq 1
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
grep -Fq 'fortad: unsupported statement at line 5' "$out/exact/forward.stderr"
grep -Fq 'fortad: unsupported statement at line 5' "$out/exact/reverse.stderr"

fortad_exec --mode forward --indep u,z,t,v --proc set01_lh048 --name lh048 \
    --module lh048_forward_ad --output "$out/port/lh048_forward.f90" "$case_dir/port.f90" \
    >"$out/port/forward.stdout" 2>"$out/port/forward.stderr"
fortad_exec --mode reverse --indep u,z,t,v --dep t --proc set01_lh048 --name lh048 \
    --module lh048_reverse_ad --output "$out/port/lh048_reverse.f90" "$case_dir/port.f90" \
    >"$out/port/reverse.stdout" 2>"$out/port/reverse.stderr"
test -s "$out/port/lh048_forward.f90"
test -s "$out/port/lh048_reverse.f90"

port_status=$(compile_capture "$case_dir/port.f90" "$out/port/port.o" "$out/port/port.status" free)
hand_status=$(compile_capture "$case_dir/hand.f90" "$out/port/hand.o" "$out/port/hand.status" free)
jvp_status=$(compile_capture "$out/port/lh048_forward.f90" "$out/port/jvp.o" "$out/port/jvp.status" free)
reverse_status=$(compile_capture "$out/port/lh048_reverse.f90" "$out/port/reverse.o" "$out/port/reverse.status" free)
test "$port_status" -eq 0
test "$hand_status" -eq 0
test "$jvp_status" -eq 0
test "$reverse_status" -ne 0
grep -Fq 'Duplicate symbol' "$out/port/reverse.o.stderr"
grep -Fq 't_b' "$out/port/reverse.o.stderr"
python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fqx 'oracle_status: pass' "$out/oracle.txt"
harness_status=$(compile_capture "$case_dir/harness.f90" "$out/port/harness.o" "$out/port/harness.status" free)
test "$harness_status" -eq 0
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/port/harness" \
    "$out/port/port.o" "$out/port/hand.o" "$out/port/jvp.o" "$out/port/harness.o"
"$out/port/harness" >"$out/port/run.txt"
grep -Fqx 'oracle_status: pass' "$out/port/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh048\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_source" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_strict_compile: program=%s tangent=%s reverse=%s\n' "$exact_program_status" "$exact_d_status" "$exact_b_status"
    printf 'stored_references: program_d.msg program_b.msg\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' "$fresh_p_status" "$fresh_d_status" "$fresh_b_status"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="unsupported statement at line 5"\n' "$exact_fortad_forward_status"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="unsupported statement at line 5"\n' "$exact_fortad_reverse_status"
    printf 'fortad_bounded_forward_generation: pass\n'
    printf 'fortad_bounded_forward_strict_compile: %s\n' "$jvp_status"
    printf 'fortad_bounded_reverse_generation: pass\n'
    printf 'fortad_bounded_reverse_strict_compile: refusal status=%s diagnostic="Duplicate symbol t_b"\n' "$reverse_status"
    printf 'independent_oracle: hand evaluation, central-difference sweep, and adjoint identity\n'
    cat "$out/oracle.txt"
    cat "$out/port/run.txt"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_d.f program_b.f program_d.msg program_b.msg)
    printf 'bounded_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh048/manifest.toml cases/tapenade-set01/lh048/notes.md cases/tapenade-set01/lh048/port.f90 cases/tapenade-set01/lh048/hand.f90 cases/tapenade-set01/lh048/harness.f90 cases/tapenade-set01/lh048/oracle.py cases/tapenade-set01/lh048/run.sh cases/tapenade-set01/lh048/test_contract.py)
} >"$result"
cat "$result"
