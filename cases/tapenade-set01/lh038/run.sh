#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh038 and its bounded forward port.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh038"
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
strict_free=(-std=f2018 -pedantic-errors -Wall -Wextra -ffree-line-length-none -fno-lto)
source_dir="$tapenade_repo/nonRegressions/set01/lh038"

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for message in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -e "$source_dir/$message"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh038.XXXXXX)
clean_fortad_repo=
cleanup() {
    rm -rf "$out"
    if test -n "$clean_fortad_repo"; then
        rm -rf "$clean_fortad_repo"
    fi
}
trap cleanup EXIT

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)
if test "$fortad_original_commit" != "$required_fortad_commit" || \
   test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$root/../fortad-lh038-clean.XXXXXX")
    rmdir "$clean_fortad_repo"
    git clone --shared --quiet "$fortad_checkout" "$clean_fortad_repo"
    git -C "$clean_fortad_repo" checkout --detach --quiet "$required_fortad_commit"
    fortad_repo="$clean_fortad_repo"
    fortad_worktree="temporary clean clone pinned to required commit"
else
    fortad_repo="$fortad_checkout"
    fortad_worktree="supplied checkout clean and pinned"
fi
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"

mkdir -p "$out/include" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/mod" "$out/port"
ln -s "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/include/DIFFSIZES.inc"

compile_fixed() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_fixed[@]}" -I"$source_dir" -I"$out/include" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_free() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

run_expected_failure() {
    local label=$1 diagnostic=$2
    shift 2
    set +e
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
    test "$status" -ne 0
    grep -Fq "$diagnostic" "$out/$label.stderr"
}

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
if test ! -x "$tapenade_repo/bin/tapenade" || \
   test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"
fortad="$fortad_repo/build/fo/bin/fortad"
test -x "$tapenade"
test -x "$fortad"

upstream_start=$(date +%s.%N)
for source in program program_p program_d program_b program_dv; do
    compile_fixed "$source_dir/$source.f" "upstream_$source"
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')
for source in program program_p program_d program_b program_dv; do
    test "$(cat "$out/upstream_${source}.status")" = 0
done

tapenade_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -root top -o lh038 "$source_dir/program.f") \
    >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -root top -o lh038 "$source_dir/program.f") \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -root top -o lh038 "$source_dir/program.f") \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')
test -s "$out/tapenade/parser/lh038_p.f"
test -s "$out/tapenade/forward/lh038_d.f"
test -s "$out/tapenade/reverse/lh038_b.f"
compile_fixed "$out/tapenade/parser/lh038_p.f" tapenade_parser
compile_fixed "$out/tapenade/forward/lh038_d.f" tapenade_forward
compile_fixed "$out/tapenade/reverse/lh038_b.f" tapenade_reverse
for label in tapenade_parser tapenade_forward tapenade_reverse; do
    test "$(cat "$out/$label.status")" = 0
done

exact_start=$(date +%s.%N)
for mode in forward reverse; do
    run_expected_failure "fortad_exact_${mode}" \
        "fortad: unsupported statement at line 3" \
        "$fortad" --mode "$mode" --indep x --dep x --proc top \
        --name "lh038_exact_${mode}" --module "lh038_exact_${mode}_ad" \
        --output "$out/fortad_exact_${mode}.f90" "$source_dir/program.f"
    test ! -e "$out/fortad_exact_${mode}.f90"
done
exact_stop=$(date +%s.%N)
exact_seconds=$(awk -v a="$exact_start" -v b="$exact_stop" \
    'BEGIN {printf "%.6f", b-a}')

port_start=$(date +%s.%N)
"$fortad" --mode forward --indep pi,x --dep x --proc set01_lh038 \
    --name lh038_forward --module lh038_forward_ad \
    --output "$out/port/lh038_forward.f90" "$case_dir/port.f90" \
    >"$out/fortad-port-forward.stdout" 2>"$out/fortad-port-forward.stderr"
printf '%s\n' "$?" >"$out/fortad-port-forward.status"
test "$(cat "$out/fortad-port-forward.status")" = 0
"$fortad" --mode reverse --indep pi,x --dep x --proc set01_lh038 \
    --name lh038_reverse --module lh038_reverse_ad \
    --output "$out/port/lh038_reverse.f90" "$case_dir/port.f90" \
    >"$out/fortad-port-reverse.stdout" 2>"$out/fortad-port-reverse.stderr"
printf '%s\n' "$?" >"$out/fortad-port-reverse.status"
test "$(cat "$out/fortad-port-reverse.status")" = 0
test -s "$out/port/lh038_forward.f90"
test -s "$out/port/lh038_reverse.f90"
port_stop=$(date +%s.%N)
port_seconds=$(awk -v a="$port_start" -v b="$port_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_free "$case_dir/port.f90" port
compile_free "$case_dir/hand.f90" hand
compile_free "$out/port/lh038_forward.f90" fortad_forward
compile_free "$out/port/lh038_reverse.f90" fortad_reverse
compile_free "$case_dir/harness.f90" harness
test "$(cat "$out/port.status")" = 0
test "$(cat "$out/hand.status")" = 0
test "$(cat "$out/fortad_forward.status")" = 0
test "$(cat "$out/fortad_reverse.status")" = 1
grep -Fq "Duplicate symbol" "$out/fortad_reverse.stderr"
test "$(cat "$out/harness.status")" = 0

"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/port.o" "$out/hand.o" "$out/fortad_forward.o" "$out/harness.o" \
    >"$out/link.stdout" 2>"$out/link.stderr"
set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
run_status=$?
set -e
test "$run_status" = 0
grep -Fqx 'oracle_status: pass' "$out/run.txt"
python3 "$case_dir/oracle.py" >"$out/python-oracle.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh038\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'entry_point: top(x); bounded_port: set01_lh038(pi,x); indep: pi,x; dep: x\n'
    printf 'commands:\n'
    printf 'exact_compile: %s\n' "$fc ${strict_fixed[*]} -I$source_dir -I$out/include -c <each of program.f program_p.f program_d.f program_b.f program_dv.f>"
    printf 'fresh_parser: tapenade -p -root top -o lh038 program.f\n'
    printf 'fresh_tangent: tapenade -d -root top -o lh038 program.f\n'
    printf 'fresh_reverse: tapenade -b -root top -o lh038 program.f\n'
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'upstream_exact_source_compile: pass\n'
    printf 'upstream_stored_references_strict_compile: program_p.f=pass program_d.f=pass program_b.f=pass program_dv.f=pass\n'
    printf 'tapenade_fresh_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_diagnostics: parser=none tangent=none reverse=none\n'
    printf 'fortad_exact_probe_seconds: %s\n' "$exact_seconds"
    printf 'fortad_exact_result: expected-refusal forward_status=%s reverse_status=%s diagnostic="fortad: unsupported statement at line 3 (COMMON /ext/)"\n' \
        "$(cat "$out/fortad_exact_forward.status")" "$(cat "$out/fortad_exact_reverse.status")"
    printf 'fortad_port_transform_seconds: %s\n' "$port_seconds"
    printf 'fortad_port_result: forward=pass reverse=expected-refusal-generated-compile\n'
    printf 'fortad_port_forward_status: %s\n' "$(cat "$out/fortad-port-forward.status")"
    printf 'fortad_port_reverse_generation_status: %s\n' "$(cat "$out/fortad-port-reverse.status")"
    printf 'fortad_port_reverse_compile_status: %s\n' "$(cat "$out/fortad_reverse.status")"
    printf 'fortad_port_reverse_diagnostic: Duplicate symbol x_b in formal argument list\n'
    printf 'independent_oracle: hand closed form, central finite differences, and adjoint identity\n'
    cat "$out/run.txt"
    cat "$out/python-oracle.txt"
    printf 'oracle_status: pass\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_generated_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum lh038_p.f lh038_p.msg)
    (cd "$out/tapenade/forward" && sha256sum lh038_d.f lh038_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum lh038_b.f lh038_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh038/manifest.toml \
        cases/tapenade-set01/lh038/notes.md cases/tapenade-set01/lh038/port.f90 \
        cases/tapenade-set01/lh038/hand.f90 cases/tapenade-set01/lh038/harness.f90 \
        cases/tapenade-set01/lh038/oracle.py cases/tapenade-set01/lh038/run.sh \
        cases/tapenade-set01/lh038/test_contract.py)
} >"$result"
cat "$result"
