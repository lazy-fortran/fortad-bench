#!/usr/bin/env bash
# Validate Tapenade nonRegressions/set01/lh037 and its bounded FortAD port.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh037"
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -fno-lto)
source_dir="$tapenade_repo/nonRegressions/set01/lh037"

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
command -v fo >/dev/null
test -x /usr/bin/time
test -d "$fortad_checkout/.git" || test -f "$fortad_checkout/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_b.f program_d.f program_dv.f program_p.f \
              program_b.msg program_d.msg program_dv.msg program_p.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh037.XXXXXX)
clean_fortad_repo=
cleanup() {
    if test -n "$clean_fortad_repo"; then
        rm -rf "$clean_fortad_repo"
    fi
    rm -rf "$out"
}
trap cleanup EXIT

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)
if test "$fortad_original_commit" != "$required_fortad_commit" || test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$root/../fortad-lh037-clean.XXXXXX")
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

mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/port"
fortad_bin="$fortad_repo/build/fo/bin/fortad"
if test ! -x "$fortad_bin"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
fi
test -x "$fortad_bin"
tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
test -x "$tapenade"

compile_fixed() {
    local source=$1 label=$2
    set +e
    "$fc" "${strict_fixed[@]}" -I"$source_dir" -J"$out/mod" "$source" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_free() {
    local source=$1 label=$2
    "$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
}

upstream_start=$(date +%s.%N)
for source in program.f program_b.f program_d.f program_dv.f program_p.f; do
    compile_fixed "$source_dir/$source" "upstream-${source%.f}"
    test "$(cat "$out/upstream-${source%.f}.status")" -ne 0
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" 'BEGIN {printf "%.6f", b-a}')

tapenade_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -root assgoto1 -o lh037 "$source_dir/program.f") \
    >"$out/tapenade-parser.stdout" 2>"$out/tapenade-parser.stderr"
(cd "$out/tapenade/forward" && "$tapenade" -d -root assgoto1 -o lh037 "$source_dir/program.f") \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
(cd "$out/tapenade/reverse" && "$tapenade" -b -root assgoto1 -o lh037 "$source_dir/program.f") \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" 'BEGIN {printf "%.6f", b-a}')

for generated in "$out/tapenade/parser/lh037_p.f" "$out/tapenade/forward/lh037_d.f" \
                 "$out/tapenade/reverse/lh037_b.f"; do
    test -s "$generated"
done
compile_fixed "$out/tapenade/parser/lh037_p.f" tapenade-parser
compile_fixed "$out/tapenade/forward/lh037_d.f" tapenade-forward
compile_fixed "$out/tapenade/reverse/lh037_b.f" tapenade-reverse
for mode in parser forward reverse; do
    test "$(cat "$out/tapenade-$mode.status")" -ne 0
    grep -Fq 'Deleted feature: ASSIGN statement' "$out/tapenade-$mode.stderr"
done

fortad_probe() {
    local mode=$1 output=$2 label=$3
    set +e
    "$fortad_bin" --mode "$mode" --indep a,b,c --proc assgoto1 \
        --name "lh037_exact_${mode}" --module "lh037_exact_${mode}_ad" \
        --output "$output" "$source_dir/program.f" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    test "$status" -ne 0
    grep -Fq 'fortad: unsupported statement at line 8' "$out/$label.log"
    test ! -s "$output"
    printf '%s\n' "$status" >"$out/$label.status"
}

fortad_exact_start=$(date +%s.%N)
fortad_probe forward "$out/lh037-exact-forward.f90" exact-forward
fortad_probe reverse "$out/lh037-exact-reverse.f90" exact-reverse
fortad_exact_stop=$(date +%s.%N)
fortad_exact_seconds=$(awk -v a="$fortad_exact_start" -v b="$fortad_exact_stop" 'BEGIN {printf "%.6f", b-a}')

fortad_port_start=$(date +%s.%N)
"$fortad_bin" --mode forward --indep a0,b0,c0 --proc set01_lh037 \
    --name lh037_forward --module lh037_forward_ad --output "$out/port/lh037_forward.f90" \
    "$case_dir/port.f90" >"$out/fortad-port-forward.log" 2>&1
for dep in a b c; do
    "$fortad_bin" --mode reverse --indep a0,b0,c0 --dep "$dep" --proc set01_lh037 \
        --name "lh037_reverse_${dep}" --module "lh037_reverse_${dep}_ad" \
        --output "$out/port/lh037_reverse_${dep}.f90" "$case_dir/port.f90" \
        >"$out/fortad-port-reverse-${dep}.log" 2>&1
done
fortad_port_stop=$(date +%s.%N)
fortad_port_seconds=$(awk -v a="$fortad_port_start" -v b="$fortad_port_stop" 'BEGIN {printf "%.6f", b-a}')
for generated in "$out/port/lh037_forward.f90" "$out/port/lh037_reverse_a.f90" \
                 "$out/port/lh037_reverse_b.f90" "$out/port/lh037_reverse_c.f90"; do
    test -s "$generated"
done

compile_start=$(date +%s.%N)
compile_free "$case_dir/port.f90" port
compile_free "$case_dir/hand.f90" hand
compile_free "$out/port/lh037_forward.f90" fortad-forward
compile_free "$out/port/lh037_reverse_a.f90" fortad-reverse-a
compile_free "$out/port/lh037_reverse_b.f90" fortad-reverse-b
compile_free "$out/port/lh037_reverse_c.f90" fortad-reverse-c
compile_free "$case_dir/harness.f90" harness
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/port.o" "$out/hand.o" "$out/harness.o" "$out/fortad-forward.o" \
    "$out/fortad-reverse-a.o" "$out/fortad-reverse-b.o" "$out/fortad-reverse-c.o" \
    >"$out/link.stdout" 2>"$out/link.stderr"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" 'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"
oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh037\n'
    printf 'classification: unsupported-invalid-upstream-fortran\n'
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
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'upstream_exact_strict_compile: expected-refusal program=1 program_b=1 program_d=1 program_dv=1 program_p=1\n'
    printf 'upstream_stored_reference_strict_compile: program_p=1 program_d=1 program_b=1 program_dv=1\n'
    printf 'upstream_diagnostic_contract: ASSIGN deleted; REAL*8 nonstandard; program_dv missing DIFFSIZES.inc\n'
    printf 'tapenade_fresh_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile: parser=expected-refusal tangent=expected-refusal reverse=expected-refusal\n'
    printf 'fortad_exact_probe_seconds: %s\n' "$fortad_exact_seconds"
    printf 'fortad_exact_result: expected-refusal forward_status=%s reverse_status=%s diagnostic="fortad: unsupported statement at line 8 (assigned GOTO)"\n' \
        "$(cat "$out/exact-forward.status")" "$(cat "$out/exact-reverse.status")"
    printf 'fortad_port_transform_seconds: %s\n' "$fortad_port_seconds"
    printf 'fortad_port_result: pass-transform-compile-runtime\n'
    printf 'fortad_port_modes: forward=pass reverse=a,b,c=pass\n'
    printf 'port_precondition: b-c>8 before entry; nonterminating alternate path is intentionally outside the bounded port\n'
    printf 'port_compile_seconds: %s\n' "$compile_seconds"
    printf 'independent_oracle: closed-form JVP/VJP, central finite differences, and adjoint identity\n'
    cat "$out/runtime-metrics.txt"
    cat "$out/run.txt"
    printf '%s\n' "$oracle_output"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_dv.msg program_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh037/manifest.toml \
        cases/tapenade-set01/lh037/notes.md cases/tapenade-set01/lh037/port.f90 \
        cases/tapenade-set01/lh037/hand.f90 cases/tapenade-set01/lh037/harness.f90 \
        cases/tapenade-set01/lh037/oracle.py cases/tapenade-set01/lh037/run.sh \
        cases/tapenade-set01/lh037/test_contract.py)
} >"$result"
cat "$result"
